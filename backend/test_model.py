import tensorflow as tf
import numpy as np
from PIL import Image
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / 'frontend' / 'assets'
model_path = ASSETS_DIR / 'model.tflite'

labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
          'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'del', 'nothing', 'space']

print("Loading TFLite model...")
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print(f"Input: {input_details}")
print(f"Output: {output_details}")

test_images = sorted((ASSETS_DIR / 'images').glob('*_test.jpg'))

print("\nTesting predictions...")
passed = 0
for path in test_images:
    expected = path.stem.replace('_test', '')
    try:
        img = Image.open(path).convert('RGB')
        img = img.resize((64, 64))
        img_array = np.array(img, dtype=np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        interpreter.set_tensor(input_details[0]['index'], img_array)
        interpreter.invoke()

        output = interpreter.get_tensor(output_details[0]['index'])
        predicted_idx = np.argmax(output)
        confidence = float(np.max(output))
        predicted_label = labels[predicted_idx]

        match = predicted_label == expected
        passed += int(match)
        status = "PASS" if match else "FAIL"
        print(f"{status} Image: {path.name} | Predicted: {predicted_label} | Confidence: {confidence*100:.1f}%")
    except Exception as e:
        print(f"Error with {path}: {e}")

print(f"\nSummary: {passed}/{len(test_images)} test images predicted correctly")
