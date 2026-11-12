import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D
from tensorflow.keras.models import Model
import os

# 1. Cargar las imágenes desde la carpeta descargada de Roboflow
ruta_dataset = "./bird-classifications-v2/train" 

print("Cargando dataset...")
train_dataset = tf.keras.utils.image_dataset_from_directory(
    ruta_dataset, 
    image_size=(224, 224), # Tamaño estándar para MobileNet
    batch_size=32
)

# Guardar los nombres de las aves (los nombres de las subcarpetas)
nombres_aves = train_dataset.class_names
print(f"Especies detectadas: {nombres_aves}")

# Usamos un modelo preentrenado pero le quitamos la última capa para poner las nuestras
modelo_base = MobileNetV2(input_shape=(224, 224, 3), include_top=False, weights='imagenet')
modelo_base.trainable = False # Congelamos el aprendizaje previo para que sea más rápido

# Añadimos nuestra capa final que clasificará específicamente nuestras aves
x = GlobalAveragePooling2D()(modelo_base.output)
salida = Dense(len(nombres_aves), activation='softmax')(x)
modelo = Model(inputs=modelo_base.input, outputs=salida)

# 3. Compilar y Entrenar
modelo.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

print("\n--- Iniciando Entrenamiento (esto puede tardar unos minutos) ---")
# 25 epochs para probar; para más precisión puedes subirlo a 10 o 20
modelo.fit(train_dataset, epochs=50)

# 4. Guardar las etiquetas en un archivo de texto
with open('etiquetas.txt', 'w') as f:
    f.write('\n'.join(nombres_aves))
print("\n[OK] Archivo 'etiquetas.txt' generado.")

# 5. Convertir y exportar a TensorFlow Lite (.tflite)
print("Convirtiendo modelo para Android...")
converter = tf.lite.TFLiteConverter.from_keras_model(modelo)
tflite_model = converter.convert()

with open('modelo_aves.tflite', 'wb') as f:
    f.write(tflite_model)
print("[OK] Archivo 'modelo_aves.tflite' generado con éxito.")