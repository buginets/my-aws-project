# ~/my-aws-project/app.py
from flask import Flask, request, jsonify
import mysql.connector
app = Flask(__name__)

db = mysql.connector.connect(host="mysql", user="root", password="rootpass", database="todo")
cursor = db.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS tasks (id INT AUTO_INCREMENT PRIMARY KEY, task VARCHAR(255))")

@app.route('/tasks', methods=['GET', 'POST'])
def tasks():
    if request.method == 'POST':
        task = request.json.get('task')
        cursor.execute("INSERT INTO tasks (task) VALUES (%s)", (task,))
        db.commit()
        return jsonify({"status": "added"})
    cursor.execute("SELECT * FROM tasks")
    return jsonify([{"id": r[0], "task": r[1]} for r in cursor.fetchall()])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)