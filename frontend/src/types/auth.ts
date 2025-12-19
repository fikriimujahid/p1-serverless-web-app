export interface User {
  email: string;
  userId: string;
}

export interface AuthContextType {
  isAuthenticated: boolean;
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string) => Promise<SignupResult>;
  confirmSignup: (email: string, code: string) => Promise<void>;
  resendConfirmation: (email: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
  idToken: string | null;
}

export interface SignupResult {
  userConfirmed: boolean;
  destination?: string;
  deliveryMedium?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface SignupRequest {
  email: string;
  password: string;
  confirmPassword: string;
}