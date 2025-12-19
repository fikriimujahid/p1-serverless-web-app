import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { NotesService } from '../../services/NotesService';
import { responseFormatter } from '../../utils/response';
import { logger } from '../../utils/logger';
import { NotFoundError, ValidationError } from '../../types/errors';

const service = new NotesService();

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return responseFormatter.success({}, 200);
    }

    const userId = event.requestContext.authorizer?.claims?.sub;

    if (!userId) {
      return responseFormatter.error('Unauthorized', 401);
    }

    logger.info('Write handler invoked', { path: event.path, method: event.httpMethod });

    // Create note
    if (event.path === '/notes' && event.httpMethod === 'POST') {
      const body = JSON.parse(event.body || '{}');
      const note = await service.createNote(userId, body);
      return responseFormatter.success(note, 201);
    }

    // Update note
    if (event.path.startsWith('/notes/') && event.httpMethod === 'PUT') {
      const noteId = event.pathParameters?.id;

      if (!noteId) {
        return responseFormatter.error('Note ID is required', 400);
      }

      const body = JSON.parse(event.body || '{}');
      const note = await service.updateNote(userId, noteId, body);
      return responseFormatter.success(note, 200);
    }

    // Delete note
    if (event.path.startsWith('/notes/') && event.httpMethod === 'DELETE') {
      const noteId = event.pathParameters?.id;

      if (!noteId) {
        return responseFormatter.error('Note ID is required', 400);
      }

      await service.deleteNote(userId, noteId);
      return responseFormatter.success(null, 204);
    }

    return responseFormatter.error('Not Found', 404);
  } catch (error: any) {
    logger.error('Write handler error', error);

    if (error instanceof NotFoundError) {
      return responseFormatter.error(error.message, 404);
    }

    if (error instanceof ValidationError) {
      return responseFormatter.error(error.message, 400);
    }

    return responseFormatter.error('Internal Server Error', 500);
  }
};