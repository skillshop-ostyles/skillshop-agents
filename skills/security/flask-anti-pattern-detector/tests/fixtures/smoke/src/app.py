from flask import Flask, render_template_string, session, request
import pickle

app = Flask(__name__)
app.config['SECRET_KEY'] = 'this-is-a-hardcoded-secret-key'

@app.route('/')
def index():
    return 'Hello, world!'

@app.route('/greet')
def greet():
    name = request.args.get('name', 'world')
    return render_template_string('<h1>Hello {{ name }}!</h1>', name=name)

@app.route('/unsafe-greet')
def unsafe_greet():
    template = '<h1>Hello ' + request.args.get('name', 'world') + '!</h1>'
    return render_template_string(template)

@app.route('/load-data', methods=['POST'])
def load_data():
    data = pickle.loads(request.data)
    return {'loaded': data}

@app.route('/eval-expr')
def eval_expr():
    expr = request.args.get('expr', '1+1')
    result = eval(expr)
    return {'result': result}

@app.route('/login', methods=['POST'])
def login():
    username = request.form.get('username')
    session['user'] = username
    session.permanent = True
    return {'login': 'ok'}

@app.route('/safe')
def safe():
    return {'status': 'ok'}

if __name__ == '__main__':
    app.run(debug=True)
