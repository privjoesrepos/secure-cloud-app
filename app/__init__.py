import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from .config import DevelopmentConfig, ProductionConfig

db = SQLAlchemy()


def create_app(config_override=None):
    app = Flask(__name__)

    env = os.environ.get("APP_ENV", "development")
    if env == "production":
        app.config.from_object(ProductionConfig)
    else:
        app.config.from_object(DevelopmentConfig)

    if not app.config.get("SQLALCHEMY_DATABASE_URI"):
        raise RuntimeError(
            "DATABASE_URL environment variable is not set. "
            "Cannot start the application without a database connection."
        )

    if config_override:
        app.config.update(config_override)

    db.init_app(app)

    from .routes import main_bp
    app.register_blueprint(main_bp)

    with app.app_context():
        db.create_all()

    return app
