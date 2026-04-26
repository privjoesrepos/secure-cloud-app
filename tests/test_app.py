import os
os.environ['DATABASE_URL'] = 'sqlite:///:memory:'  # noqa: E402

import pytest  # noqa: E402
from app import create_app, db  # noqa: E402


@pytest.fixture
def app():
    app = create_app()
    app.config['TESTING'] = True

    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


def test_health_check(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'


def test_create_user(client):
    response = client.post('/users', json={
        "username": "aaa",
        "email": "aaa@devops.com"
    })
    assert response.status_code == 201
    assert response.json['username'] == 'aaa'


def test_get_users(client):
    payload = {"username": "aaa", "email": "aaa@devops.com"}
    client.post('/users', json=payload)
    response = client.get('/users')
    assert response.status_code == 200
    assert len(response.json) == 1
    assert response.json[0]['email'] == 'aaa@devops.com'


def test_duplicate_user(client):
    payload = {"username": "aaa", "email": "aaa@devops.com"}
    client.post('/users', json=payload)
    resp = client.post('/users', json={"username": "aaa", "email": "diff@dev.com"})
    assert resp.status_code == 409
    assert 'already exists' in resp.json['error']