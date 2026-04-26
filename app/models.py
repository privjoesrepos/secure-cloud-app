from . import db


class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)

    # Helper method to convert the object to a dictionary for our JSON responses
    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email
        }