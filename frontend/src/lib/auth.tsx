'use client';

import React, { createContext, useContext, ReactNode } from 'react';
import {
  CognitoIdentityProviderClient,
  InitiateAuthCommand,
  SignUpCommand,
  ConfirmSignUpCommand,
  ResendConfirmationCodeCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { env } from './env';
import type { AuthContextType, User, SignupResult } from '@/types/auth';

const AuthContext = createContext<AuthContextType | undefined>(undefined);
const isDev = process.env.NODE_ENV === 'development';

const cognitoClient = new CognitoIdentityProviderClient({ region: env.region });

type DecodedToken = {
  email?: unknown;
  sub?: unknown;
  [key: string]: unknown;
};

function decodeJWT(token: string): DecodedToken {
  const base64Url = token.split('.')[1];
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const jsonPayload = decodeURIComponent(
    atob(base64)
      .split('')
      .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
      .join('')
  );
  return JSON.parse(jsonPayload);
}

export function useAuth(): AuthContextType {
  const [isAuthenticated, setIsAuthenticated] = React.useState(false);
  const [user, setUser] = React.useState<User | null>(null);
  const [idToken, setIdToken] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);

  React.useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = () => {
    const token = localStorage.getItem('idToken');
    if (token) {
      try {
        const decoded = decodeJWT(token);
        const email = typeof decoded.email === 'string' ? decoded.email : null;
        const userId = typeof decoded.sub === 'string' ? decoded.sub : null;

        if (!email || !userId) {
          throw new Error('Decoded token missing required claims');
        }

        setIdToken(token);
        setUser({
          email,
          userId,
        });
        setIsAuthenticated(true);
      } catch (error) {
        console.error('Failed to decode token:', error);
        localStorage.removeItem('idToken');
      }
    }
    setIsLoading(false);
  };

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      const loginPayload = {
        ClientId: env.cognitoClientId,
        AuthFlow: 'USER_PASSWORD_AUTH',
        AuthParameters: {
          USERNAME: email,
          PASSWORD: '***REDACTED***',
        },
      };
      if (isDev) console.log('🔐 Login Request Payload:', loginPayload);

      const response = await cognitoClient.send(
        new InitiateAuthCommand({
          ClientId: env.cognitoClientId,
          AuthFlow: 'USER_PASSWORD_AUTH',
          AuthParameters: {
            USERNAME: email,
            PASSWORD: password,
          },
        })
      );

      if (isDev) console.log('✅ Login Response:', {
        ...response,
        AuthenticationResult: response.AuthenticationResult ? {
          ...response.AuthenticationResult,
          IdToken: response.AuthenticationResult.IdToken ? '***TOKEN***' : undefined,
          AccessToken: response.AuthenticationResult.AccessToken ? '***TOKEN***' : undefined,
          RefreshToken: response.AuthenticationResult.RefreshToken ? '***TOKEN***' : undefined,
        } : undefined,
      });

      const token = response.AuthenticationResult?.IdToken;
      if (!token) throw new Error('No token in response');

      localStorage.setItem('idToken', token);
      setIdToken(token);
      const decoded = decodeJWT(token);
      const decodedEmail = typeof decoded.email === 'string' ? decoded.email : null;
      const decodedUserId = typeof decoded.sub === 'string' ? decoded.sub : null;
      if (isDev) console.log('👤 Decoded User:', { email: decodedEmail, userId: decodedUserId });

      if (!decodedEmail || !decodedUserId) {
        throw new Error('Decoded token missing required claims');
      }

      setUser({
        email: decodedEmail,
        userId: decodedUserId,
      });
      setIsAuthenticated(true);
    } catch (error) {
      if (isDev) console.error('❌ Login Error:', error);
      setIsAuthenticated(false);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const signup = async (email: string, password: string): Promise<SignupResult> => {
    setIsLoading(true);
    try {
      const signupPayload = {
        ClientId: env.cognitoClientId,
        Username: email,
        Password: '***REDACTED***',
        UserAttributes: [
          { Name: 'email', Value: email },
        ],
      };
      if (isDev) console.log('📝 Signup Request Payload:', signupPayload);

      const response = await cognitoClient.send(
        new SignUpCommand({
          ClientId: env.cognitoClientId,
          Username: email,
          Password: password,
          UserAttributes: [
            { Name: 'email', Value: email },
          ],
        })
      );

      if (isDev) console.log('✅ Signup Response:', response);
      if (isDev) console.log('📧 User confirmation required:', !response.UserConfirmed);

      const result: SignupResult = {
        userConfirmed: !!response.UserConfirmed,
        destination: response.CodeDeliveryDetails?.Destination,
        deliveryMedium: response.CodeDeliveryDetails?.DeliveryMedium,
      };

      return result;
    } catch (error) {
      if (isDev) console.error('❌ Signup Error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const confirmSignup = async (email: string, code: string) => {
    setIsLoading(true);
    try {
      if (isDev) console.log('🔐 Confirm Signup Payload:', { email, code: '***REDACTED***' });

      const response = await cognitoClient.send(
        new ConfirmSignUpCommand({
          ClientId: env.cognitoClientId,
          Username: email,
          ConfirmationCode: code,
        })
      );

      if (isDev) console.log('✅ Confirm Signup Response:', response);
    } catch (error) {
      if (isDev) console.error('❌ Confirm Signup Error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const resendConfirmation = async (email: string) => {
    setIsLoading(true);
    try {
      if (isDev) console.log('📨 Resend Confirmation Payload:', { email });

      const response = await cognitoClient.send(
        new ResendConfirmationCodeCommand({
          ClientId: env.cognitoClientId,
          Username: email,
        })
      );

      if (isDev) console.log('✅ Resend Confirmation Response:', response);
    } catch (error) {
      if (isDev) console.error('❌ Resend Confirmation Error:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('idToken');
    setIdToken(null);
    setUser(null);
    setIsAuthenticated(false);
    
    // Clear all cached queries to prevent data leakage between users
    if (typeof window !== 'undefined') {
      import('../app/query-provider').then(({ queryClient }) => {
        queryClient.clear();
      });
    }
  };

  return {
    isAuthenticated,
    user,
    login,
    signup,
    confirmSignup,
    resendConfirmation,
    logout,
    isLoading,
    idToken,
  };
}

// AuthProvider component
export function AuthProvider({ children }: { children: ReactNode }) {
  return (
    <AuthContext.Provider value={useAuth()}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuthContext() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuthContext must be used within AuthProvider');
  }
  return context;
}