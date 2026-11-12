import cv2

def iniciar_consola_aves():
    # Inicializar la cámara de la PC
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("Error: No se pudo acceder a la cámara.")
        return

    print("--- SISTEMA DE RASTREO Y CONSOLA DE AVES ---")
    print("Presiona 'q' en tu teclado para cerrar la consola.")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Error al leer el fotograma de la cámara.")
            break

        # Convertir a escala de grises para optimizar procesamiento en consola
        grises = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Simulación de registro de consola en tiempo real
        cv2.putText(frame, "MODO CONSOLA: Analizando fotograma...", (30, 40), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        # Mostrar la ventana de consola
        cv2.imshow("Consola - Deteccion de Aves", frame)

        # Salir con la tecla 'q'
        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("Cerrando sesión de consola...")
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    iniciar_consola_aves()