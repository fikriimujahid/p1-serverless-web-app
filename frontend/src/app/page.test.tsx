import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import LoginPage from './login/page';
import * as authLib from '@/lib/auth';

// Mock the auth module
vi.mock('@/lib/auth', () => ({
  useAuth: vi.fn(),
}));

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
  }),
}));

describe('LoginPage', () => {
  const mockLogin = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(authLib.useAuth).mockReturnValue({
      isAuthenticated: false,
      user: null,
      login: mockLogin,
      signup: vi.fn(),
      confirmSignup: vi.fn(),
      resendConfirmation: vi.fn(),
      logout: vi.fn(),
      isLoading: false,
      idToken: null,
    } as ReturnType<typeof authLib.useAuth>);
  });

  it('renders login form elements', () => {
    render(<LoginPage />);
    
    expect(screen.getByText('Notes App')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('you@example.com')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('••••••••')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /login/i })).toBeInTheDocument();
  });

  it('displays signup link', () => {
    render(<LoginPage />);
    
    const signupLink = screen.getByRole('link', { name: /sign up/i });
    expect(signupLink).toBeInTheDocument();
    expect(signupLink).toHaveAttribute('href', '/signup');
  });

  it('updates email and password fields on input', async () => {
    const user = userEvent.setup();
    render(<LoginPage />);
    
    const emailInput = screen.getByPlaceholderText('you@example.com') as HTMLInputElement;
    const passwordInput = screen.getByPlaceholderText('••••••••') as HTMLInputElement;

    await user.type(emailInput, 'test@example.com');
    await user.type(passwordInput, 'password123');

    expect(emailInput.value).toBe('test@example.com');
    expect(passwordInput.value).toBe('password123');
  });

  it('calls login function on form submit', async () => {
    const user = userEvent.setup();
    render(<LoginPage />);
    
    const emailInput = screen.getByPlaceholderText('you@example.com');
    const passwordInput = screen.getByPlaceholderText('••••••••');
    const submitButton = screen.getByRole('button', { name: /login/i });

    await user.type(emailInput, 'test@example.com');
    await user.type(passwordInput, 'password123');
    await user.click(submitButton);

    expect(mockLogin).toHaveBeenCalledWith('test@example.com', 'password123');
  });

  it('disables form when loading', () => {
    vi.mocked(authLib.useAuth).mockReturnValue({
      isAuthenticated: false,
      user: null,
      login: mockLogin,
      signup: vi.fn(),
      confirmSignup: vi.fn(),
      resendConfirmation: vi.fn(),
      logout: vi.fn(),
      isLoading: true,
      idToken: null,
    } as ReturnType<typeof authLib.useAuth>);

    render(<LoginPage />);
    
    const submitButton = screen.getByRole('button', { name: /logging in/i });
    expect(submitButton).toBeDisabled();
  });

  it('displays error message on login failure', async () => {
    const user = userEvent.setup();
    mockLogin.mockRejectedValue(new Error('Invalid credentials'));

    render(<LoginPage />);
    
    const emailInput = screen.getByPlaceholderText('you@example.com');
    const passwordInput = screen.getByPlaceholderText('••••••••');
    const submitButton = screen.getByRole('button', { name: /login/i });

    await user.type(emailInput, 'test@example.com');
    await user.type(passwordInput, 'wrongpassword');
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
    });
  });

//   it('clears error message on new attempt', async () => {
//     const user = userEvent.setup();
//     mockLogin.mockRejectedValueOnce(new Error('Invalid credentials'));
//     mockLogin.mockResolvedValueOnce(undefined);

//     render(<LoginPage />);
    
//     const emailInput = screen.getByPlaceholderText('you@example.com');
//     const passwordInput = screen.getByPlaceholderText('••••••••');
//     const submitButton = screen.getByRole('button', { name: /login/i });

//     // First attempt - fails
//     await user.type(emailInput, 'test@example.com');
//     await user.type(passwordInput, 'wrongpassword');
//     await user.click(submitButton);

//     await waitFor(() => {
//       expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
//     });

//     // Second attempt - clears error before submitting
//     await user.clear(passwordInput);
//     await user.type(passwordInput, 'correctpassword');
    
//     // Error should be cleared on form submit
//     const errorDiv = screen.queryByText('Invalid credentials');
//     if (errorDiv) {
//       expect(errorDiv).not.toBeInTheDocument();
//     }
//   });

  it('requires email and password fields', () => {
    render(<LoginPage />);
    
    const emailInput = screen.getByPlaceholderText('you@example.com') as HTMLInputElement;
    const passwordInput = screen.getByPlaceholderText('••••••••') as HTMLInputElement;

    expect(emailInput.required).toBe(true);
    expect(passwordInput.required).toBe(true);
  });
});