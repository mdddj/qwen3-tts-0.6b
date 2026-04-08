#!/usr/bin/env python3
"""Qwen3 TTS CLI wrapper for local text-to-speech generation."""

from __future__ import annotations

import argparse
import inspect
import os
import shutil
import sys
from pathlib import Path
from typing import Any


DEFAULT_MODEL_ID = "Qwen/Qwen3-TTS-12Hz-0.6B-Base"
DEFAULT_CN_ENDPOINT = "https://hf-mirror.com"


def apply_proxy_env(http_proxy: str | None, https_proxy: str | None) -> None:
    if http_proxy:
        os.environ["http_proxy"] = http_proxy
        os.environ["HTTP_PROXY"] = http_proxy
    if https_proxy:
        os.environ["https_proxy"] = https_proxy
        os.environ["HTTPS_PROXY"] = https_proxy


def configure_hf_endpoint(cn_mirror: bool, hf_endpoint: str | None) -> None:
    if cn_mirror and not hf_endpoint:
        hf_endpoint = DEFAULT_CN_ENDPOINT
    if hf_endpoint:
        os.environ["HF_ENDPOINT"] = hf_endpoint


def configure_cache_dir(cache_dir: str | None) -> str | None:
    if not cache_dir:
        return None
    resolved = str(Path(cache_dir).expanduser().resolve())
    os.environ["HF_HOME"] = resolved
    os.environ["HUGGINGFACE_HUB_CACHE"] = str(Path(resolved) / "hub")
    return resolved


def ensure_external_dependencies() -> None:
    if shutil.which("sox"):
        return

    raise RuntimeError(
        "Missing external dependency: sox\n"
        "Install SoX and make sure it is available on PATH.\n"
        "Verify with: sox --version\n"
        "Windows download: https://sourceforge.net/projects/sox/"
    )


def read_text_from_args(text: str | None, text_file: str | None) -> str:
    if text:
        return text.strip()
    if not text_file:
        raise ValueError("Either --text or --text-file is required.")
    content = Path(text_file).read_text(encoding="utf-8").strip()
    if not content:
        raise ValueError(f"Text file is empty: {text_file}")
    return content


def detect_model_family(model_id: str) -> str:
    lowered = model_id.lower()
    if "customvoice" in lowered:
        return "custom"
    if "voicedesign" in lowered:
        return "design"
    if lowered.endswith("-base") or "-base" in lowered:
        return "clone"
    return "unknown"


def load_model_class():
    # Newer versions expose Qwen3TTSModel at package root.
    try:
        from qwen_tts import Qwen3TTSModel

        return Qwen3TTSModel
    except Exception:
        from qwen_tts.model import Qwen3TTSModel

        return Qwen3TTSModel


def call_with_compatible_kwargs(fn, options: list[dict[str, Any]]) -> Any:
    last_error: Exception | None = None
    try:
        signature = inspect.signature(fn)
        accepts_var_kwargs = any(
            p.kind == inspect.Parameter.VAR_KEYWORD
            for p in signature.parameters.values()
        )
    except Exception:
        signature = None
        accepts_var_kwargs = True

    for kwargs in options:
        filtered = {k: v for k, v in kwargs.items() if v is not None}
        if signature and not accepts_var_kwargs:
            filtered = {k: v for k, v in filtered.items() if k in signature.parameters}
        try:
            return fn(**filtered)
        except TypeError as exc:
            last_error = exc
            continue

    if last_error:
        raise last_error
    raise RuntimeError("No compatible call signature found.")


def maybe_persist_audio(model, result: Any, output_path: Path) -> None:
    if output_path.exists():
        return

    synthesis = getattr(model, "synthesis", None)
    if callable(synthesis):
        try:
            synthesis(result, output_path=str(output_path))
        except Exception:
            pass
    if output_path.exists():
        return

    if isinstance(result, tuple) and len(result) >= 2:
        wavs, sr = result[0], result[1]
        audio = wavs[0] if isinstance(wavs, (list, tuple)) else wavs
        try:
            import soundfile as sf
        except Exception as exc:
            raise RuntimeError(
                "Model returned waveform tuple but soundfile is unavailable to write WAV."
            ) from exc
        sf.write(str(output_path), audio, int(sr))
        return

    raise RuntimeError(
        "Model call finished but no output audio file was produced. "
        "Check qwen-tts version compatibility."
    )


def resolve_voice_mode(args: argparse.Namespace) -> str:
    if args.voice_mode != "auto":
        return args.voice_mode
    if args.spk_audio or args.spk_text:
        return "clone"
    if args.speaker:
        return "custom"
    if args.instruct:
        return "design"
    return "base"


def validate_voice_inputs(args: argparse.Namespace, mode: str) -> None:
    if (args.spk_audio and not args.spk_text) or (args.spk_text and not args.spk_audio):
        raise ValueError("--spk-audio and --spk-text must be provided together.")
    if mode == "clone" and (not args.spk_audio or not args.spk_text):
        raise ValueError("clone mode requires --spk-audio and --spk-text.")
    if mode == "custom" and not args.speaker:
        raise ValueError("custom mode requires --speaker.")
    if mode == "design" and not args.instruct:
        raise ValueError("design mode requires --instruct.")


def validate_model_capability(model_id: str, mode: str) -> None:
    family = detect_model_family(model_id)

    if mode == "base":
        raise ValueError(
            "plain text-only synthesis is not supported by the current qwen-tts "
            "public API for Qwen3-TTS models. Use one of these instead:\n"
            "  - clone mode with a Base model plus --spk-audio and --spk-text\n"
            "  - custom mode with a *-CustomVoice model\n"
            "  - design mode with a *-VoiceDesign model"
        )

    if family == "clone" and mode != "clone":
        raise ValueError(
            f"model '{model_id}' is a Base/clone model and only supports clone mode. "
            "Provide --spk-audio and --spk-text, or switch --model-id to a "
            "CustomVoice/VoiceDesign model."
        )
    if family == "custom" and mode != "custom":
        raise ValueError(
            f"model '{model_id}' is a CustomVoice model and should be used with custom mode."
        )
    if family == "design" and mode != "design":
        raise ValueError(
            f"model '{model_id}' is a VoiceDesign model and should be used with design mode."
        )


def synthesize_audio(
    model,
    mode: str,
    text: str,
    output_path: Path,
    spk_audio: str | None,
    spk_text: str | None,
    speaker: str | None,
    instruct: str | None,
    language: str | None,
) -> None:
    output_str = str(output_path)

    if mode == "clone":
        clone_fn = getattr(model, "generate_voice_clone", None)
        if not callable(clone_fn):
            raise RuntimeError(
                "Installed qwen-tts does not expose generate_voice_clone for this model."
            )
        result = call_with_compatible_kwargs(
            clone_fn,
            [
                {
                    "text": text,
                    "language": language,
                    "ref_audio": spk_audio,
                    "ref_text": spk_text,
                    "output_path": output_str,
                },
                {
                    "text": text,
                    "language": language,
                    "spk_audio_path": spk_audio,
                    "spk_text": spk_text,
                    "output_path": output_str,
                },
                {
                    "text": text,
                    "language": language,
                    "spk_audio": spk_audio,
                    "spk_text": spk_text,
                    "output_path": output_str,
                },
            ],
        )
        maybe_persist_audio(model, result, output_path)
        return

    if mode == "custom":
        custom_fn = getattr(model, "generate_custom_voice", None)
        if not callable(custom_fn):
            raise RuntimeError(
                "Installed qwen-tts does not expose generate_custom_voice for this model."
            )
        result = call_with_compatible_kwargs(
            custom_fn,
            [
                {
                    "text": text,
                    "speaker": speaker,
                    "instruct": instruct,
                    "output_path": output_str,
                },
                {"text": text, "speaker": speaker, "instruct": instruct},
            ],
        )
        maybe_persist_audio(model, result, output_path)
        return

    if mode == "design":
        design_fn = getattr(model, "generate_voice_design", None)
        if not callable(design_fn):
            raise RuntimeError(
                "Installed qwen-tts does not expose generate_voice_design for this model."
            )
        result = call_with_compatible_kwargs(
            design_fn,
            [
                {"text": text, "instruct": instruct, "output_path": output_str},
                {"text": text, "instruct": instruct},
            ],
        )
        maybe_persist_audio(model, result, output_path)
        return

    raise RuntimeError(
        "Unsupported mode 'base'. Base models in qwen-tts public API are clone-only."
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Synthesize speech with Qwen3-TTS-12Hz-0.6B-Base."
    )
    parser.add_argument("--text", help="Input text to synthesize.")
    parser.add_argument("--text-file", help="Read input text from a UTF-8 file.")
    parser.add_argument(
        "--output",
        required=True,
        help="Output WAV path, e.g. outputs/reply.wav",
    )
    parser.add_argument(
        "--model-id",
        default=DEFAULT_MODEL_ID,
        help=f"Hugging Face model id (default: {DEFAULT_MODEL_ID})",
    )
    parser.add_argument(
        "--cache-dir",
        help="Model cache directory. Useful for customer machine deployment.",
    )
    parser.add_argument(
        "--download-only",
        action="store_true",
        help="Only download/cache model on first run, no TTS generation.",
    )
    parser.add_argument(
        "--local-files-only",
        action="store_true",
        help="Do not access network; only load model from local cache.",
    )
    parser.add_argument(
        "--voice-mode",
        choices=["auto", "base", "clone", "custom", "design"],
        default="auto",
        help=(
            "Voice generation mode: auto infer from inputs, or force mode. "
            "clone=reference voice, custom=predefined speaker+style, design=text style design."
        ),
    )
    parser.add_argument(
        "--speaker",
        help="Speaker name for custom mode, e.g. Cherry.",
    )
    parser.add_argument(
        "--instruct",
        help="Style instruction for custom/design mode, e.g. Speak in a warm podcast tone.",
    )
    parser.add_argument(
        "--language",
        help="Optional language hint for clone mode, e.g. Chinese or English.",
    )
    parser.add_argument(
        "--spk-audio",
        help="Reference audio path for style transfer (optional).",
    )
    parser.add_argument(
        "--spk-text",
        help="Reference transcript text for --spk-audio (optional).",
    )
    parser.add_argument(
        "--cn-mirror",
        action="store_true",
        help=f"Use China mirror endpoint by setting HF_ENDPOINT={DEFAULT_CN_ENDPOINT}",
    )
    parser.add_argument(
        "--hf-endpoint",
        help="Custom Hugging Face endpoint, e.g. https://hf-mirror.com",
    )
    parser.add_argument("--http-proxy", help="HTTP proxy URL.")
    parser.add_argument("--https-proxy", help="HTTPS proxy URL.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.download_only and not args.text and not args.text_file:
        print("error: pass --text or --text-file, or use --download-only", file=sys.stderr)
        return 2

    voice_mode = resolve_voice_mode(args)
    try:
        validate_voice_inputs(args, voice_mode)
        validate_model_capability(args.model_id, voice_mode)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    apply_proxy_env(args.http_proxy, args.https_proxy)
    configure_hf_endpoint(args.cn_mirror, args.hf_endpoint)
    resolved_cache = configure_cache_dir(args.cache_dir)

    try:
        ensure_external_dependencies()
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    text = None
    if not args.download_only:
        try:
            text = read_text_from_args(args.text, args.text_file)
        except Exception as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2

    output_path = Path(args.output).expanduser().resolve()
    if not args.download_only:
        output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        Qwen3TTSModel = load_model_class()
    except Exception as exc:
        print(
            "error: failed to import qwen_tts. Install dependencies first:\n"
            "  python3 -m pip install -U qwen-tts\n"
            "If you are in China, try:\n"
            "  python3 -m pip install -U qwen-tts -i https://pypi.tuna.tsinghua.edu.cn/simple\n"
            f"detail: {exc}",
            file=sys.stderr,
        )
        return 1

    print("info: loading model (first run may download model files)...", file=sys.stderr)
    try:
        model = Qwen3TTSModel.from_pretrained(
            args.model_id,
            local_files_only=args.local_files_only,
        )
    except TypeError:
        # Backward compatibility if qwen_tts does not expose local_files_only.
        model = Qwen3TTSModel.from_pretrained(args.model_id)
    except Exception as exc:
        print(
            "error: model loading failed. If this is first run, check network/proxy/mirror.\n"
            "tips:\n"
            "  - add --cn-mirror in China\n"
            "  - set --http-proxy / --https-proxy\n"
            "  - for offline mode, pre-download with --download-only and then use --local-files-only\n"
            f"detail: {exc}",
            file=sys.stderr,
        )
        return 1

    if args.download_only:
        print("ok: model is cached and ready.")
        print(f"model: {args.model_id}")
        if resolved_cache:
            print(f"cache_dir: {resolved_cache}")
        if os.environ.get("HF_ENDPOINT"):
            print(f"hf_endpoint: {os.environ['HF_ENDPOINT']}")
        if os.environ.get("HTTP_PROXY"):
            print(f"http_proxy: {os.environ['HTTP_PROXY']}")
        if os.environ.get("HTTPS_PROXY"):
            print(f"https_proxy: {os.environ['HTTPS_PROXY']}")
        return 0

    try:
        synthesize_audio(
            model=model,
            mode=voice_mode,
            text=text,  # type: ignore[arg-type]
            output_path=output_path,
            spk_audio=args.spk_audio,
            spk_text=args.spk_text,
            speaker=args.speaker,
            instruct=args.instruct,
            language=args.language,
        )
    except Exception as exc:
        print(
            "error: synthesis failed.\n"
            "tips:\n"
            "  - clone mode: provide both --spk-audio and --spk-text\n"
            "  - custom mode: provide --speaker and optional --instruct\n"
            "  - design mode: provide --instruct\n"
            f"detail: {exc}",
            file=sys.stderr,
        )
        return 1

    print(f"ok: generated {output_path}")
    print(f"model: {args.model_id}")
    print(f"voice_mode: {voice_mode}")
    if resolved_cache:
        print(f"cache_dir: {resolved_cache}")
    if os.environ.get("HF_ENDPOINT"):
        print(f"hf_endpoint: {os.environ['HF_ENDPOINT']}")
    if os.environ.get("HTTP_PROXY"):
        print(f"http_proxy: {os.environ['HTTP_PROXY']}")
    if os.environ.get("HTTPS_PROXY"):
        print(f"https_proxy: {os.environ['HTTPS_PROXY']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
