from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.contrib.auth import get_user_model, authenticate
from .serializers import UserRegisterSerializer, TripTemplateSerializer
from .models import TripTemplate
from rest_framework_simplejwt.tokens import RefreshToken
import logging

User = get_user_model()

# Logger for this module
logger = logging.getLogger(__name__)

def generate_and_send_otp(user):
    """
    Supabase handles OTP delivery/verification.
    
    """
    logger.debug("Supabase is responsible for OTP delivery for user=%s", user.email)
    # Clear any backend OTP fields to avoid stale values.
    user.otp = None
    user.otp_created_at = None
    user.save()


class RegisterView(generics.CreateAPIView):
    serializer_class = UserRegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        user.is_active = False
        user.save()
        generate_and_send_otp(user)
        return Response({
            "message": "User registered. Please verify OTP.",
            "email": user.email
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        user = authenticate(username=email, password=password)

        if user is not None:
            # Supabase handles OTP delivery for sign-in; backend no longer sends OTPs.
            generate_and_send_otp(user)
            return Response({
                "message": "Use Supabase OTP sign-in; backend will not send OTPs.",
                "email": email
            }, status=status.HTTP_200_OK)
        
        return Response({"error": "Invalid email or password"}, status=status.HTTP_401_UNAUTHORIZED)


class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get('email')
        otp_entered = request.data.get('otp')

        try:
            user = User.objects.get(email=email)
            if user.otp == otp_entered:
                user.otp = None
                user.save()
                if not user.is_active:
                    user.is_active = True
                    user.save()
                
                refresh = RefreshToken.for_user(user)
                return Response({
                    "message": "Login Successful",
                    "refresh": str(refresh),
                    "access": str(refresh.access_token),
                }, status=status.HTTP_200_OK)
            else:
                return Response({"error": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)
        except User.DoesNotExist:
            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)


class CheckEmailExistsView(APIView):
    """
    Check if an email already exists in the database
    GET /users/check-email/?email=example@example.com
    Returns: {"exists": true/false}
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        email = request.query_params.get('email', '').strip().lower()
        
        if not email:
            return Response(
                {"error": "Email parameter is required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        exists = User.objects.filter(email=email).exists()
        logger.debug(f"Email check: {email} - exists={exists}")
        
        return Response(
            {"exists": exists, "email": email},
            status=status.HTTP_200_OK
        )

# --- NEW VIEW: MANAGE TRIP TEMPLATES ---
class TripTemplateListCreateView(generics.ListCreateAPIView):
    """
    GET: Returns list of templates for the logged-in user.
    POST: Saves a new template.
    """
    serializer_class = TripTemplateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Only return templates belonging to the current user
        return TripTemplate.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        # Automatically attach the current user to the template
        serializer.save(user=self.request.user)