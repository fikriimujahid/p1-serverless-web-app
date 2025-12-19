export const env = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001',
  cognitoClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID || '',
  cognitoUserPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID || '',
  region: process.env.NEXT_PUBLIC_REGION || 'us-east-1',
};

// Validation at startup
if (!env.cognitoClientId) {
  throw new Error('Missing NEXT_PUBLIC_COGNITO_CLIENT_ID');
}
if (!env.cognitoUserPoolId) {
  throw new Error('Missing NEXT_PUBLIC_COGNITO_USER_POOL_ID');
}