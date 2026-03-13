from flask import Flask
import os
import pymssql

app = Flask(__name__)

def init_db():
    conn = pymssql.connect(
        server=os.environ.get("DB_SERVER"),
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD"),
        database=os.environ.get("DB_NAME")
    )
    cursor = conn.cursor()
    cursor.execute("""
        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'service')
        CREATE TABLE service (
            id INT IDENTITY(1,1) PRIMARY KEY,
            nom NVARCHAR(255) NOT NULL
        )
    """)
    conn.commit()
    conn.close()

@app.route("/")
def index():
    return "Hello World"

@app.route("/services")
def services():
    return "Je suis une page qui présente les services"

if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("APP_PORT"))
    app.run(host="0.0.0.0", port=port, debug=True)
