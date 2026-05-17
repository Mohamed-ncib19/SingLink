import firebase_admin
from firebase_admin import credentials, firestore

if not firebase_admin._apps:
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()


def retrieve_history(user_id):
    try:
        doc = db.collection('users').document(user_id).get()
        if doc.exists:
            data = doc.to_dict()
            return data.get('history', [])
        return []
    except Exception as e:
        print(f"Error retrieving history: {e}")
        return []


def store_translation(user_id, translation):
    try:
        doc_ref = db.collection('users').document(user_id)
        doc = doc_ref.get()
        
        if doc.exists:
            current_history = doc.to_dict().get('history', [])
            current_history.insert(0, translation)
            doc_ref.update({'history': current_history})
        else:
            doc_ref.set({'history': [translation]})
    except Exception as e:
        print(f"Error storing translation: {e}")