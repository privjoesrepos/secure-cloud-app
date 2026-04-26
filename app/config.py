import os


class Config:
    SQLALCHEMY_DATABASE_URI = os.environ.get(
        "DATABASE_URL",
        "mysql+pymysql://root:password@localhost:3306/app_db"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
