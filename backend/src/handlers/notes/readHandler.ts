import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { NotesService } from '../../services/NotesService';
import { responseFormatter } from '../../utils/response';
import { logger } from '../../utils/logger';
import { NotFoundError, ValidationError } from '../../types/errors';

const service = new NotesService();

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userId = event.requestContext.authorizer?.claims?.sub;

    if (!userId) {
      return responseFormatter.error('Unauthorized', 401);
    }

    logger.info('Read handler invoked', { path: event.path, method: event.httpMethod });

    // List notes
    if (event.path === '/notes' && event.httpMethod === 'GET') {
      const limit = parseInt(event.queryStringParameters?.limit || '20');
      const nextToken = event.queryStringParameters?.nextToken;

      const result = await service.listNotes(userId, limit, nextToken);
      return responseFormatter.success(result, 200);
    }

    // Get note by ID
    if (event.path.startsWith('/notes/') && event.httpMethod === 'GET') {
      const noteId = event.pathParameters?.id;

      if (!noteId) {
        return responseFormatter.error('Note ID is required', 400);
      }

      const note = await service.getNote(userId, noteId);
      return responseFormatter.success(note, 200);
    }

    return responseFormatter.error('Not Found', 404);
  } catch (error: any) {
    logger.error('Read handler error', error);

    if (error instanceof NotFoundError) {
      return responseFormatter.error(error.message, 404);
    }

    if (error instanceof ValidationError) {
      return responseFormatter.error(error.message, 400);
    }

    return responseFormatter.error('Internal Server Error', 500);
  }
};