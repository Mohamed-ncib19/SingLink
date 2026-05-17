import sys
import tensorflow as tf
import numpy as np
from PIL import Image
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
model_path = PROJECT_ROOT / 'frontend' / 'assets' / 'model.tflite'
labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
          'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'del', 'nothing', 'space']

print("Loading model...")
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print("Model ready!\n")

def predict_image(image_path):
    img = Image.open(image_path).convert('RGB')
    img = img.resize((64, 64))
    img_array = np.array(img, dtype=np.float32) / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    
    interpreter.set_tensor(input_details[0]['index'], img_array)
    interpreter.invoke()
    
    output = interpreter.get_tensor(output_details[0]['index'])
    predicted_idx = np.argmax(output)
    confidence = float(np.max(output))
    predicted_label = labels[predicted_idx]
    
    return predicted_label, confidence

if len(sys.argv) > 1:
    image_path = sys.argv[1]
else:
    image_path = input("Enter image path: ").strip().strip('"')

try:
    label, confidence = predict_image(image_path)
    print(f"\nPredicted: {label}")
    print(f"Confidence: {confidence * 100:.2f}%")
except Exception as e:
    print(f"Error: {e}")
