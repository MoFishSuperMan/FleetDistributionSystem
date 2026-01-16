from django.contrib.auth.backends import BaseBackend
from django.contrib.auth.models import User
from .models import Dispatcher, Driver

class FleetAuthBackend(BaseBackend):
    def authenticate(self, request, username=None, password=None, role=None, **kwargs):
        """
        Authenticate against Dispatcher or Driver tables.
        role: 'dispatcher' or 'driver'
        username: dispatcher_id or driver_id
        """
        if role == 'dispatcher':
            try:
                dispatcher = Dispatcher.objects.get(dispatcher_id=username)
                if dispatcher.password == password:  # Note: Use hashing in production
                    user, created = User.objects.get_or_create(username=f"disp_{username}")
                    user.first_name = dispatcher.name
                    user.save()
                    return user
            except Dispatcher.DoesNotExist:
                return None
        
        elif role == 'driver':
            try:
                driver = Driver.objects.get(driver_id=username)
                if driver.password == password:  # Added password check
                    user, created = User.objects.get_or_create(username=f"driver_{username}")
                    user.first_name = driver.name
                    user.save()
                    return user
            except Driver.DoesNotExist:
                return None
                
        return None

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
