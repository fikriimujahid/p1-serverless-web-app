import { APIGatewayProxyResult } from 'aws-lambda';

export const responseFormatter = {
  success: (body: any, statusCode: number = 200): APIGatewayProxyResult => ({
    statusCode,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  }),

  error: (message: string, statusCode: number = 500): APIGatewayProxyResult => ({
    statusCode,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message }),
  }),
};