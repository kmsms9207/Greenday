from flask import Flask, request, jsonify
import mysql.connector
from werkzeug.security import generate_password_hash

app=Flask("greenday")


@app.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    password_hash=generate_password_hash(password)

    db_config ={
    'host' : 'localhost',
    'user' : 'root',
    'password' : '1234',
    'database' : 'greenday_db'
}

    try:
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE username = %s",(username,))
        if cursor.fetchone():
            return jsonify({'error': '이미 사용 중인 사용자 이름입니다.'}),409
        
        cursor.execute("SELECT *FROM users WHERE email = %s", (email,))
        if cursor.fetchone():
            return jsonify({'error':'이미 등록된 이메일입니다.'}),409
        
        
        sql = "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)"
        cursor.execute(sql, (username,email,password))
        conn.commit()
        return jsonify({"message" : "회원가입 성공!"}),201
    except mysql.connector.Error as err:
        return jsonify({"error" : str(err)}),500
    finally:
        cursor.close()
        conn.close()



if __name__ =='__main__':
    app.run(debug=True)