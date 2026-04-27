from flask import Blueprint, jsonify, request
from . import db
from .models import User

main_bp = Blueprint('main', __name__)


@main_bp.route('/', methods=['GET'])
def index():
    return jsonify({
        "status": "success",
        "message": "Welcome to the Secure Cloud App API."
    }), 200


@main_bp.route('/health', methods=['GET'])
def health():
    try:
        db.session.execute(db.text('SELECT 1'))
        return jsonify(
            {"status": "healthy", "database": "connected"}
        ), 200
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e)
        }), 503


@main_bp.route('/users', methods=['POST'])
def create_user():
    data = request.get_json()

    if not data or not data.get('username') or not data.get('email'):
        return jsonify({"error": "Username and email are required"}), 400

    if User.query.filter_by(username=data['username']).first():
        return jsonify({"error": "Username already exists"}), 409

    if User.query.filter_by(email=data['email']).first():
        return jsonify({"error": "Email already in use"}), 409

    new_user = User(username=data['username'], email=data['email'])
    db.session.add(new_user)
    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify({"error": "Could not create user"}), 500

    return jsonify(new_user.to_dict()), 201


@main_bp.route('/users', methods=['GET'])
def get_users():
    users = User.query.all()
    return jsonify([user.to_dict() for user in users]), 200
