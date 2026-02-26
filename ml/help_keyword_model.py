# # import os
# # import numpy as np
# # import librosa
# # import tensorflow as tf
# # from sklearn.model_selection import train_test_split
# # from tensorflow.keras.models import Sequential
# # from tensorflow.keras.layers import Dense, Dropout
# # from tensorflow.keras.utils import to_categorical

# # # path

# # BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# # DATASET_PATH = os.path.join(BASE_DIR, "..", "dataset")

# # SAMPLE_RATE = 16000
# # N_MFCC = 13
# # EPOCHS = 50
# # BATCH_SIZE = 8

# # # FEATURE EXTRACTION
# # def extract_features(file_path):
# #     y, sr = librosa.load(file_path, sr=SAMPLE_RATE)
# #     mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
# #     return np.mean(mfcc, axis=1)

# # # LOAD DATASET
# # def load_dataset():
# #     X, y = [], []

# #     print(" Dataset path:", DATASET_PATH)

# #     for label, folder in enumerate(["not_help", "help"]):
# #         folder_path = os.path.join(DATASET_PATH, folder)
# #         print(f"\n Checking: {folder_path}")

# #         if not os.path.exists(folder_path):
# #             print(" Folder not found")
# #             continue

# #         for file in os.listdir(folder_path):
# #             if file.lower().endswith(".wav"):
# #                 file_path = os.path.join(folder_path, file)
# #                 print(" Loading:", file)

# #                 try:
# #                     features = extract_features(file_path)
# #                     X.append(features)
# #                     y.append(label)
# #                 except Exception as e:
# #                     print(" Error:", e)

# #     X = np.array(X)
# #     y = to_categorical(y, num_classes=2)
# #     return X, y

# # # MAIN
# # print("\n Loading dataset...")
# # X, y = load_dataset()
# # print(f"\n Dataset loaded. Samples: {len(X)}")

# # if len(X) == 0:
# #     raise RuntimeError(" No .wav files found. Fix dataset structure.")

# # # TRAIN / TEST SPLIT
# # X_train, X_test, y_train, y_test = train_test_split(
# #     X, y, test_size=0.2, random_state=42
# # )

# # # MODEL
# # model = Sequential([
# #     Dense(64, activation='relu', input_shape=(N_MFCC,)),
# #     Dropout(0.3),
# #     Dense(32, activation='relu'),
# #     Dropout(0.3),
# #     Dense(2, activation='softmax')
# # ])

# # model.compile(
# #     optimizer='adam',
# #     loss='categorical_crossentropy',
# #     metrics=['accuracy']
# # )

# # model.summary()

# # # TRAIN
# # print("\n Training model...")
# # model.fit(
# #     X_train,
# #     y_train,
# #     epochs=EPOCHS,
# #     batch_size=BATCH_SIZE,
# #     validation_data=(X_test, y_test)
# # )

# # # SAVE TRAINED MODEL (KERAS FORMAT)
# # KERAS_MODEL_PATH = os.path.join(BASE_DIR, "help_keyword_model.keras")
# # model.save(KERAS_MODEL_PATH)
# # print(f"\n Keras model saved at:\n{KERAS_MODEL_PATH}")

# # # EXPORT SAVEDMODEL (FOR TFLITE)
# # # 
# # SAVED_MODEL_DIR = os.path.join(BASE_DIR, "saved_model")
# # model.export(SAVED_MODEL_DIR)
# # print(f"\n SavedModel exported at:\n{SAVED_MODEL_DIR}")

# # # CONVERT TO TFLITE

# # converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_MODEL_DIR)
# # tflite_model = converter.convert()

# # TFLITE_PATH = os.path.join(BASE_DIR, "help_keyword_model.tflite")
# # with open(TFLITE_PATH, "wb") as f:
# #     f.write(tflite_model)

# # print(f"\n TFLite model saved at:\n{TFLITE_PATH}")

# import os
# import numpy as np
# import librosa
# import tensorflow as tf
# from sklearn.model_selection import train_test_split
# from tensorflow.keras.models import Sequential
# from tensorflow.keras.layers import Dense, Dropout
# from tensorflow.keras.utils import to_categorical
# from tensorflow.keras.callbacks import EarlyStopping

# # PATH
# BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# DATASET_PATH = os.path.join(BASE_DIR, "..", "dataset")

# SAMPLE_RATE = 16000
# N_MFCC = 13
# EPOCHS = 50
# BATCH_SIZE = 8

# # FEATURE EXTRACTION
# def extract_features(file_path):
#     y, sr = librosa.load(file_path, sr=SAMPLE_RATE)

#     mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
#     mfcc = np.mean(mfcc, axis=1)

#     return mfcc

# # LOAD DATASET
# def load_dataset():
#     X, y = [], []

#     class_counts = {}

#     print("Dataset path:", DATASET_PATH)

#     for label, folder in enumerate(["not_help", "help"]):
#         folder_path = os.path.join(DATASET_PATH, folder)
#         class_counts[folder] = 0

#         if not os.path.exists(folder_path):
#             print("Missing:", folder_path)
#             continue

#         for file in os.listdir(folder_path):
#             if file.lower().endswith(".wav"):
#                 file_path = os.path.join(folder_path, file)

#                 try:
#                     features = extract_features(file_path)
#                     X.append(features)
#                     y.append(label)
#                     class_counts[folder] += 1
#                 except Exception as e:
#                     print("Error:", e)

#     print("\nClass distribution:")
#     print(class_counts)

#     X = np.array(X)
#     y = to_categorical(y, num_classes=2)

#     return X, y

# # LOAD DATA
# print("\nLoading dataset...")
# X, y = load_dataset()
# print(f"Samples: {len(X)}")

# if len(X) == 0:
#     raise RuntimeError("No audio found.")

# # ⭐ NORMALIZATION (MOST IMPORTANT FIX)
# mean = np.mean(X)
# std = np.std(X) + 1e-6
# X = (X - mean) / std

# print(f"\nNormalized MFCC -> mean: {np.mean(X):.4f}, std: {np.std(X):.4f}")

# # SPLIT
# X_train, X_test, y_train, y_test = train_test_split(
#     X, y, test_size=0.2, random_state=42
# )

# # MODEL
# model = Sequential([
#     Dense(64, activation='relu', input_shape=(N_MFCC,)),
#     Dropout(0.3),
#     Dense(32, activation='relu'),
#     Dropout(0.3),
#     Dense(2, activation='softmax')
# ])

# model.compile(
#     optimizer='adam',
#     loss='categorical_crossentropy',
#     metrics=['accuracy']
# )

# model.summary()

# # ⭐ EARLY STOPPING
# early_stop = EarlyStopping(
#     monitor="val_loss",
#     patience=6,
#     restore_best_weights=True
# )

# # TRAIN
# print("\nTraining model...")
# model.fit(
#     X_train,
#     y_train,
#     epochs=EPOCHS,
#     batch_size=BATCH_SIZE,
#     validation_data=(X_test, y_test),
#     callbacks=[early_stop]
# )

# # SAVE KERAS
# KERAS_MODEL_PATH = os.path.join(BASE_DIR, "help_keyword_model.keras")
# model.save(KERAS_MODEL_PATH)
# print("\nSaved:", KERAS_MODEL_PATH)

# # EXPORT SAVEDMODEL
# SAVED_MODEL_DIR = os.path.join(BASE_DIR, "saved_model")
# model.export(SAVED_MODEL_DIR)

# # CONVERT TFLITE
# converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_MODEL_DIR)
# tflite_model = converter.convert()

# TFLITE_PATH = os.path.join(BASE_DIR, "help_keyword_model.tflite")
# with open(TFLITE_PATH, "wb") as f:
#     f.write(tflite_model)

# print("\nTFLite saved:", TFLITE_PATH)

import os
import numpy as np
import librosa
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split

# CONFIG
SAMPLE_RATE = 16000
EPOCHS = 50
BATCH_SIZE = 8

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "..", "dataset")
)
print("Dataset:", DATASET_PATH)

print("Dataset:", DATASET_PATH)

# LOAD RAW AUDIO (1 sec)
def extract_raw(file_path):
    y, sr = librosa.load(file_path, sr=SAMPLE_RATE)

    # Normalize waveform [-1,1]
    if np.max(np.abs(y)) > 0:
        y = y / np.max(np.abs(y))

    # Pad or trim to 1 second
    if len(y) < SAMPLE_RATE:
        y = np.pad(y, (0, SAMPLE_RATE - len(y)))
    else:
        y = y[:SAMPLE_RATE]

    return y


# LOAD DATASET
X, y = [], []
class_counts = {"not_help": 0, "help": 0}

for label, folder in enumerate(["not_help", "help"]):
    folder_path = os.path.join(DATASET_PATH, folder)

    if not os.path.exists(folder_path):
        print("Missing folder:", folder_path)
        continue

    for file in os.listdir(folder_path):
        if file.endswith((".wav", ".mp3", ".ogg")):
            file_path = os.path.join(folder_path, file)
            features = extract_raw(file_path)
            X.append(features)
            y.append(label)
            class_counts[folder] += 1

print("\nClass distribution:", class_counts)

X = np.array(X, dtype=np.float32)
y = to_categorical(y, num_classes=2)

print("Total samples:", len(X))

if len(X) == 0:
    raise RuntimeError("No audio files found!")

# Global normalization
X = X / np.max(np.abs(X))

# TRAIN / TEST SPLIT
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# MODEL (Mobile Friendly)
model = Sequential([
    Dense(256, activation='relu', input_shape=(SAMPLE_RATE,)),
    Dropout(0.3),
    Dense(64, activation='relu'),
    Dropout(0.3),
    Dense(2, activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()

# TRAIN
print("\nTraining model...")
model.fit(
    X_train,
    y_train,
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    validation_data=(X_test, y_test)
)

# SAVE KERAS MODEL
keras_path = os.path.join(BASE_DIR, "help_raw_model.keras")
model.save(keras_path)
print("\nSaved Keras model:", keras_path)

# CONVERT TO TFLITE
print("\nConverting to TFLite...")

converter = tf.lite.TFLiteConverter.from_keras_model(model)


converter.target_spec.supported_ops = [
  tf.lite.OpsSet.TFLITE_BUILTINS, # Use standard TFLite ops
#   tf.lite.OpsSet.SELECT_TF_OPS    # Enable Flex ops (Fixes compatibility)
]
# Optional optimizations (recommended)
# converter.optimizations = [tf.lite.Optimize.DEFAULT]

tflite_model = converter.convert()

tflite_path = os.path.join(BASE_DIR, "help_raw_model.tflite")
with open(tflite_path, "wb") as f:
    f.write(tflite_model)

print("TFLite saved:", tflite_path)

print("\n TRAINING COMPLETE")
