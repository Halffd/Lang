# EasyOCR text recognition runner.
#
# Invoked by OcrService._recognizeWithEasyOcr:
#   python3 easyocr_recognize.py <language> <image-path>
# Prints a JSON array of recognized text blocks (paragraph mode) on
# stdout; any error goes to stderr with a non-zero exit code.
import json
import sys


def main() -> int:
    if len(sys.argv) != 3:
        sys.stderr.write("usage: easyocr_recognize.py <lang> <image>\n")
        return 2

    lang, work_path = sys.argv[1], sys.argv[2]

    import easyocr

    reader = easyocr.Reader([lang], gpu=False, verbose=False)
    result = reader.recognize(work_path, detail=0, paragraph=True)
    sys.stdout.write(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
