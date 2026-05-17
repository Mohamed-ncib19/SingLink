import os
from flask import Flask, request, send_file
from flask_cors import CORS
import json
import numpy as np
from PIL import Image
import tensorflow as tf
import io
from gtts import gTTS
from pathlib import Path
import itertools
import mediapipe as mp
from mediapipe.tasks.python import core as mp_core
from mediapipe.tasks.python.vision import hand_landmarker as mp_hand_landmarker

app = Flask(__name__)
CORS(app)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
model_path = PROJECT_ROOT / 'frontend' / 'assets' / 'model.tflite'
image_assets_path = PROJECT_ROOT / 'frontend' / 'assets' / 'images'
github_keypoint_model_path = PROJECT_ROOT / 'backend' / 'models' / 'github_keypoint_classifier.tflite'
github_keypoint_labels_path = PROJECT_ROOT / 'backend' / 'models' / 'github_keypoint_classifier_label.csv'
hand_landmarker_task_path = PROJECT_ROOT / 'backend' / 'models' / 'hand_landmarker.task'
labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 
          'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'del', 'nothing', 'space']
supported_image_labels = {
    path.stem[:-5] for path in image_assets_path.glob('*_test.jpg')
}
minimum_detection_confidence = 0.85
reference_similarity_threshold = 0.38
reference_margin_threshold = 0.02
minimum_reference_std = 8.0
minimum_skin_ratio = 0.02
github_landmark_confidence_threshold = 0.75


def _preprocess_for_model(img):
    img = img.resize((64, 64))
    img_array = np.array(img, dtype=np.float32)
    img_array = img_array / 255.0
    return np.expand_dims(img_array, axis=0)


def _preprocess_landmarks(hand_landmarks):
    points = [[landmark.x, landmark.y] for landmark in hand_landmarks]
    base_x, base_y = points[0]

    for index, point in enumerate(points):
        points[index][0] = point[0] - base_x
        points[index][1] = point[1] - base_y

    flattened = list(itertools.chain.from_iterable(points))
    max_value = max(map(abs, flattened)) if flattened else 1.0
    if max_value == 0:
        return flattened

    return [value / max_value for value in flattened]


def _build_reference_vector(img):
    grayscale = img.convert('L').resize((64, 64))
    arr = np.array(grayscale, dtype=np.float32)
    std = float(arr.std())
    if std < 1e-6:
        return np.zeros(arr.size, dtype=np.float32), std

    normalized = (arr - float(arr.mean())) / std
    return normalized.flatten(), std


def _build_skin_mask(img):
    rgb = np.array(img.convert('RGB'))
    ycbcr = np.array(img.convert('YCbCr'))

    y = ycbcr[:, :, 0]
    cb = ycbcr[:, :, 1]
    cr = ycbcr[:, :, 2]
    r = rgb[:, :, 0]
    g = rgb[:, :, 1]
    b = rgb[:, :, 2]

    return (
        (cb >= 77) & (cb <= 135) &
        (cr >= 133) & (cr <= 180) &
        (y >= 30) &
        (r > 40) &
        (g > 20) &
        (b > 10) &
        (r >= g * 0.9) &
        (r >= b * 0.9)
    )


def _extract_hand_region(img):
    mask = _build_skin_mask(img)
    skin_ratio = float(mask.mean())
    if skin_ratio < minimum_skin_ratio:
        return img, skin_ratio, False

    ys, xs = np.where(mask)
    if len(xs) == 0 or len(ys) == 0:
        return img, skin_ratio, False

    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    width = x1 - x0 + 1
    height = y1 - y0 + 1
    side = max(width, height)
    padding = int(side * 0.15)
    center_x = (x0 + x1) // 2
    center_y = (y0 + y1) // 2
    crop_side = side + (2 * padding)

    left = max(0, center_x - crop_side // 2)
    top = max(0, center_y - crop_side // 2)
    right = min(img.width, left + crop_side)
    bottom = min(img.height, top + crop_side)

    final_side = min(right - left, bottom - top)
    right = left + final_side
    bottom = top + final_side

    return img.crop((left, top, right, bottom)), skin_ratio, True


reference_vectors = {}
for path in image_assets_path.glob('*_test.jpg'):
    label = path.stem[:-5]
    with Image.open(path) as reference_image:
        hand_region, _, _ = _extract_hand_region(reference_image.convert('RGB'))
        reference_vectors[label] = _build_reference_vector(hand_region)[0]

github_keypoint_labels = [
    row.strip() for row in github_keypoint_labels_path.read_text().splitlines()
    if row.strip()
]


def _match_reference_image(img):
    vector, std = _build_reference_vector(img)
    if std < minimum_reference_std:
        return 'nothing', 0.0, 0.0

    vector_norm = float(np.linalg.norm(vector))
    if vector_norm < 1e-6:
        return 'nothing', 0.0, 0.0

    scored_labels = []
    for label, reference_vector in reference_vectors.items():
        reference_norm = float(np.linalg.norm(reference_vector))
        if reference_norm < 1e-6:
            continue

        score = float(np.dot(vector, reference_vector) /
                      (vector_norm * reference_norm))
        score = max(-1.0, min(1.0, score))
        scored_labels.append((label, score))

    scored_labels.sort(key=lambda item: item[1], reverse=True)
    if not scored_labels:
        return 'nothing', 0.0, 0.0

    best_label, best_score = scored_labels[0]
    second_score = scored_labels[1][1] if len(scored_labels) > 1 else -1.0
    return best_label, best_score, best_score - second_score

print("Loading TFLite model...")
interpreter = tf.lite.Interpreter(model_path=str(model_path))
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print("Model loaded successfully")

print("Loading GitHub landmark classifier...")
github_keypoint_interpreter = tf.lite.Interpreter(
    model_path=str(github_keypoint_model_path)
)
github_keypoint_interpreter.allocate_tensors()
github_keypoint_input_details = github_keypoint_interpreter.get_input_details()
github_keypoint_output_details = github_keypoint_interpreter.get_output_details()

github_hand_landmarker_options = mp_hand_landmarker.HandLandmarkerOptions(
    base_options=mp_core.base_options.BaseOptions(
        model_asset_path=str(hand_landmarker_task_path)
    ),
    num_hands=1,
)
github_hand_landmarker = mp_hand_landmarker.HandLandmarker.create_from_options(
    github_hand_landmarker_options
)
print("GitHub landmark classifier loaded successfully")


def _predict_with_github_landmark_model(img):
    mp_image = mp.Image(
        image_format=mp.ImageFormat.SRGB,
        data=np.array(img, dtype=np.uint8),
    )
    detection_result = github_hand_landmarker.detect(mp_image)
    if not detection_result.hand_landmarks:
        return None

    landmark_vector = _preprocess_landmarks(detection_result.hand_landmarks[0])
    github_keypoint_interpreter.set_tensor(
        github_keypoint_input_details[0]['index'],
        np.array([landmark_vector], dtype=np.float32),
    )
    github_keypoint_interpreter.invoke()
    output = github_keypoint_interpreter.get_tensor(
        github_keypoint_output_details[0]['index']
    )[0]
    predicted_index = int(np.argmax(output))

    return {
        'label': github_keypoint_labels[predicted_index],
        'confidence': float(np.max(output)),
    }


@app.route("/")
def index():
    return "SignLink API - Sign Language Recognition"


@app.route("/predict", methods=["POST"])
def predict():
    try:
        if 'image' not in request.files:
            return json.dumps({"error": "No image provided"})
        
        img = Image.open(request.files['image'].stream).convert('RGB')
        side = min(img.size)
        left = (img.width - side) // 2
        top = (img.height - side) // 2
        img = img.crop((left, top, left + side, top + side))
        img.save('debug_input.jpg')

        print(f"Image size: {img.size}, mode: {img.mode}")

        hand_region, skin_ratio, hand_detected = _extract_hand_region(img)
        print(f"Hand detected: {hand_detected}, skin ratio: {skin_ratio}")

        if not hand_detected:
            return json.dumps({
                "label": "nothing",
                "confidence": 0.0,
                "accepted": False,
                "source": "none",
                "referenceLabel": "nothing",
                "referenceScore": 0.0,
                "modelLabel": "nothing",
                "modelConfidence": 0.0,
                "handDetected": False,
                "skinRatio": skin_ratio
            })

        reference_label, reference_score, reference_margin = _match_reference_image(hand_region)
        print(
            f"Reference match: label={reference_label}, score={reference_score}, margin={reference_margin}")

        github_landmark_prediction = _predict_with_github_landmark_model(img)
        print(f"GitHub landmark prediction: {github_landmark_prediction}")

        if (
            reference_label in {'space', 'nothing'} and
            reference_score >= reference_similarity_threshold and
            reference_margin >= reference_margin_threshold
        ):
            return json.dumps({
                "label": reference_label,
                "confidence": reference_score,
                "accepted": True,
                "source": "reference",
                "referenceLabel": reference_label,
                "referenceScore": reference_score,
                "modelLabel": reference_label,
                "modelConfidence": reference_score,
                "handDetected": hand_detected,
                "skinRatio": skin_ratio
            })

        if (
            github_landmark_prediction is not None and
            github_landmark_prediction['confidence'] >= github_landmark_confidence_threshold
        ):
            return json.dumps({
                "label": github_landmark_prediction['label'],
                "confidence": github_landmark_prediction['confidence'],
                "accepted": True,
                "source": "github_landmark",
                "referenceLabel": reference_label,
                "referenceScore": reference_score,
                "modelLabel": github_landmark_prediction['label'],
                "modelConfidence": github_landmark_prediction['confidence'],
                "handDetected": hand_detected,
                "skinRatio": skin_ratio
            })

        img_array = _preprocess_for_model(hand_region)
        print(f"Preprocessed shape: {img_array.shape}")
        print(f"Preprocessed range: {img_array.min()} - {img_array.max()}")
        
        interpreter.set_tensor(input_details[0]['index'], img_array)
        interpreter.invoke()
        
        output = interpreter.get_tensor(output_details[0]['index'])
        print(f"Output shape: {output.shape}")
        print(f"Output values: {output[0]}")
        
        predicted_idx = np.argmax(output)
        confidence = float(np.max(output))
        predicted_label = labels[predicted_idx]

        accepted = False
        source = 'none'

        if (
            reference_label != 'nothing' and
            reference_score >= reference_similarity_threshold and
            reference_margin >= reference_margin_threshold
        ):
            predicted_label = reference_label
            confidence = reference_score
            accepted = True
            source = 'reference'
        elif (
            predicted_label in supported_image_labels and
            confidence >= minimum_detection_confidence
        ):
            accepted = True
            source = 'model'
        elif reference_label == 'nothing' and reference_score >= reference_similarity_threshold:
            predicted_label = 'nothing'
            confidence = reference_score
            source = 'reference'
        elif predicted_label == 'nothing':
            source = 'model'
        else:
            predicted_label = 'nothing'
            confidence = 0.0

        print(
            f"Predicted: {predicted_label} with confidence {confidence} source={source} accepted={accepted}")
        
        return json.dumps({
            "label": predicted_label,
            "confidence": confidence,
            "accepted": accepted,
            "source": source,
            "referenceLabel": reference_label,
            "referenceScore": reference_score,
            "modelLabel": labels[predicted_idx],
            "modelConfidence": float(np.max(output)),
            "handDetected": hand_detected,
            "skinRatio": skin_ratio
        })
    except Exception as e:
        import traceback
        traceback.print_exc()
        return json.dumps({"error": str(e)})


@app.route("/history", methods=["POST"])
def post_history():
    try:
        history = request.get_json()
        user_id = history["id"]
        translation = history["translation"]
        print(f"History: user={user_id}, translation={translation}")
        response = {"message": "success"}
    except Exception as e:
        response = {"message": "error", "error": str(e)}
    return json.dumps(response)


@app.route("/history", methods=["GET"])
def get_history():
    try:
        user_id = request.args.get("id")
        print(f"Get history for: {user_id}")
        response = {"history": []}
    except Exception as e:
        response = {"error": str(e)}
    return json.dumps(response)


@app.route("/register", methods=["POST"])
def register():
    try:
        account = request.get_json()
        print(f"Register: {account.get('email')}")
        response = {"id": "demo_user_id"}
    except Exception as e:
        response = {"error": str(e)}
    return json.dumps(response)


@app.route("/login", methods=["POST"])
def login():
    try:
        account = request.get_json()
        print(f"Login: {account.get('email')}")
        response = {"id": "demo_user_id"}
    except Exception as e:
        response = {"error": str(e)}
    return json.dumps(response)


@app.route("/tts", methods=["POST"])
def text_to_speech():
    try:
        data = request.get_json()
        text = data.get("text", "")
        if not text:
            return json.dumps({"error": "No text provided"})
        
        tts = gTTS(text=text, lang='en')
        audio_buffer = io.BytesIO()
        tts.write_to_fp(audio_buffer)
        audio_buffer.seek(0)
        
        return send_file(
            audio_buffer,
            mimetype='audio/mp3',
            as_attachment=False,
            download_name='tts.mp3'
        )
    except Exception as e:
        return json.dumps({"error": str(e)})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
