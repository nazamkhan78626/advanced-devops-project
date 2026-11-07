from flask import Flask, jsonify
import os, socket
app = Flask(__name__)
@app.get('/')
def home():
    return jsonify(message=os.getenv('APP_MESSAGE','Hello from EKS'), hostname=socket.gethostname(), 
version=os.getenv('APP_VERSION','v1'))
@app.get('/health')
def health():
    return jsonify(status='healthy'), 200
@app.get('/ready')
def ready():
    return jsonify(status='ready'), 200
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
