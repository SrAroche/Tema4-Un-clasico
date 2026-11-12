from flask import Flask, render_template, Response
import cv2

app = Flask(__name__)
# El 'cv2.CAP_DSHOW' ayuda en Windows a forzar la captura directa
camara = cv2.VideoCapture(0, cv2.CAP_DSHOW)
camara = cv2.VideoCapture(0)
camara.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
camara.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

def generar_video():
    while True:
        exito, frame = camara.read()
        if not exito:
            print("Error: No se pudo leer el fotograma de la cámara.")
            break
        
        # Añadir texto decorativo de la interfaz web
        cv2.putText(frame, "WEB RESPONSIVE - STREAMING", (20, 40), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 165, 0), 2)

        # Codificar imagen a JPG para transmitir vía web
        ret, buffer = cv2.imencode('.jpg', frame)
        frame_bytes = buffer.tobytes()

        yield (b'--frame\r\n'
            b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/video_feed')
def video_feed():
    return Response(generar_video(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    # Usamos threaded=True para evitar bloqueos en el navegador
    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)