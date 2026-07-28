import os


def get_twilio_client():
    from twilio.rest import Client

    return Client(
        os.getenv('TWILIO_ACCOUNT_SID', ''),
        os.getenv('TWILIO_AUTH_TOKEN', ''),
    )
