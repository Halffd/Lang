# Hugging Face TrOCR text recognition runner (local Transformers).
#
# Invoked by OcrService._recognizeWithTransformers:
#   python3 trocr_recognize.py <image-path>
# Prints the recognized text as a JSON string on stdout.
import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("usage: trocr_recognize.py <image>\n")
        return 2

    work_path = sys.argv[1]

    from PIL import Image
    from transformers import TrOCRProcessor, VisionEncoderDecoderModel

    processor = TrOCRProcessor.from_pretrained("microsoft/trocr-base-printed")
    model = VisionEncoderDecoderModel.from_pretrained(
        "microsoft/trocr-base-printed"
    )

    image = Image.open(work_path).convert("RGB")
    pixel_values = processor(images=image, return_tensors="pt").pixel_values
    generated_ids = model.generate(pixel_values)
    generated_text = processor.batch_decode(
        generated_ids, skip_special_tokens=True
    )[0]
    sys.stdout.write(json.dumps(generated_text))
    return 0


if __name__ == "__main__":
    sys.exit(main())
