import { ddb, PutCommand, GetCommand, QueryCommand, UpdateCommand, DeleteCommand } from './DynamoDBClient';
import { Note, CreateNoteInput, UpdateNoteInput } from '../types/note';
import { NotFoundError } from '../types/errors';

const TABLE = process.env.TABLE_NAME!;

export class NotesRepository {
  async create(userId: string, note: any): Promise<Note> {
    const item = {
      pk: `USER#${userId}`,
      sk: `NOTE#${note.id}`,
      ...note,
    };

    await ddb.send(
      new PutCommand({
        TableName: TABLE,
        Item: item,
      })
    );

    return note;
  }

  async list(userId: string, limit: number = 20, nextToken?: string): Promise<any> {
    const params: any = {
      TableName: TABLE,
      KeyConditionExpression: 'pk = :pk',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
      },
      Limit: limit,
    };

    if (nextToken) {
      params.ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString());
    }

    const result = await ddb.send(new QueryCommand(params));

    return {
      items: result.Items || [],
      nextToken: result.LastEvaluatedKey
        ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
        : null,
    };
  }

  async get(userId: string, noteId: string): Promise<Note> {
    const result = await ddb.send(
      new GetCommand({
        TableName: TABLE,
        Key: {
          pk: `USER#${userId}`,
          sk: `NOTE#${noteId}`,
        },
      })
    );

    if (!result.Item) {
      throw new NotFoundError(`Note ${noteId} not found`);
    }

    return result.Item as Note;
  }

  async update(userId: string, noteId: string, input: UpdateNoteInput): Promise<Note> {
    const updateExpressions: string[] = [];
    const expressionAttributeNames: any = {};
    const expressionAttributeValues: any = {};

    if (input.title !== undefined) {
      updateExpressions.push('#title = :title');
      expressionAttributeNames['#title'] = 'title';
      expressionAttributeValues[':title'] = input.title;
    }

    if (input.content !== undefined) {
      updateExpressions.push('#content = :content');
      expressionAttributeNames['#content'] = 'content';
      expressionAttributeValues[':content'] = input.content;
    }

    if (input.tags !== undefined) {
      updateExpressions.push('#tags = :tags');
      expressionAttributeNames['#tags'] = 'tags';
      expressionAttributeValues[':tags'] = input.tags;
    }

    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    try {
      const result = await ddb.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: {
            pk: `USER#${userId}`,
            sk: `NOTE#${noteId}`,
          },
          UpdateExpression: `SET ${updateExpressions.join(', ')}`,
          ExpressionAttributeNames: expressionAttributeNames,
          ExpressionAttributeValues: expressionAttributeValues,
          ConditionExpression: 'attribute_exists(pk)',
          ReturnValues: 'ALL_NEW',
        })
      );

      if (!result.Attributes) {
        throw new NotFoundError(`Note ${noteId} not found`);
      }

      return result.Attributes as Note;
    } catch (error: any) {
      if (error.name === 'ConditionalCheckFailedException') {
        throw new NotFoundError(`Note ${noteId} not found`);
      }
      throw error;
    }
  }

  async delete(userId: string, noteId: string): Promise<void> {
    await ddb.send(
      new DeleteCommand({
        TableName: TABLE,
        Key: {
          pk: `USER#${userId}`,
          sk: `NOTE#${noteId}`,
        },
      })
    );
  }
}