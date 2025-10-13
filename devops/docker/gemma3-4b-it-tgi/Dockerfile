# ---------------------------------------------------------------------------
# Gemma-3-4B-IT via Hugging Face TGI (NVIDIA GPU)
# Requirements: CUDA-capable GPU + nvidia-container-toolkit, HF token accepted for Gemma
# ---------------------------------------------------------------------------

FROM ghcr.io/huggingface/text-generation-inference:3.3.6

# Model & basic config
ARG MODEL_ID=google/gemma-3-4b-it
ENV MODEL_ID=${MODEL_ID}

# Optional quantization (leave empty for bf16/fp16).
# Options: bitsandbytes | bitsandbytes-nf4 | bitsandbytes-fp4 | eetq | gptq (prequantized)
ENV QUANTIZE=""
ENV MAX_INPUT_TOKENS=131072
ENV MAX_TOTAL_TOKENS=140000

# TGI listens on 80 by default
EXPOSE 80

ENTRYPOINT ["text-generation-launcher"]
CMD ["--model-id","${MODEL_ID}","--max-input-tokens","${MAX_INPUT_TOKENS}","--max-total-tokens","${MAX_TOTAL_TOKENS}","--dtype","bfloat16","--tokenizer-mode","auto"]

