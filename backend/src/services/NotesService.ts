import { NotesRepository } from '../repositories/NotesRepository';
import { Note, CreateNoteInput, UpdateNoteInput, ListNotesResponse } from '../types/note';
import { ValidationError, NotFoundError } from '../types/errors';
import { generateId } from '../utils/id';
import { logger } from '../utils/logger';

export class NotesService {
  private repository = new NotesRepository();

  async createNote(userId: string, input: CreateNoteInput): Promise<Note> {
    logger.info('Creating note for user', { userId });

    // Validation
    if (!input.title || input.title.trim().length === 0) {
      throw new ValidationError('Title is required');
    }

    if (input.title.length > 120) {
      throw new ValidationError('Title must be 120 characters or less');
    }

    if (!input.content || input.content.trim().length === 0) {
      throw new ValidationError('Content is required');
    }

    if (input.content.length > 10000) {
      throw new ValidationError('Content must be 10000 characters or less');
    }

    if (input.tags && input.tags.length > 10) {
      throw new ValidationError('Maximum 10 tags allowed');
    }

    // Create note
    const now = new Date().toISOString();
    const noteId = generateId();

    const note: Note = {
      id: noteId,
      title: input.title.trim(),
      content: input.content.trim(),
      tags: input.tags ?? [],
      createdAt: now,
      updatedAt: now,
    };

    await this.repository.create(userId, note);
    logger.info('Note created', { noteId });

    return note;
  }

  async listNotes(userId: string, limit: number = 20, nextToken?: string): Promise<ListNotesResponse> {
    logger.info('Listing notes for user', { userId, limit });

    const result = await this.repository.list(userId, limit, nextToken);
    return result;
  }

  async getNote(userId: string, noteId: string): Promise<Note> {
    logger.info('Getting note', { userId, noteId });

    return await this.repository.get(userId, noteId);
  }

  async updateNote(userId: string, noteId: string, input: UpdateNoteInput): Promise<Note> {
    logger.info('Updating note', { userId, noteId });

    // Validation
    if (input.title !== undefined) {
      if (!input.title || input.title.trim().length === 0) {
        throw new ValidationError('Title cannot be empty');
      }
      if (input.title.length > 120) {
        throw new ValidationError('Title must be 120 characters or less');
      }
    }

    if (input.content !== undefined) {
      if (input.content.length > 10000) {
        throw new ValidationError('Content must be 10000 characters or less');
      }
    }

    if (input.tags !== undefined && input.tags.length > 10) {
      throw new ValidationError('Maximum 10 tags allowed');
    }

    const note = await this.repository.update(userId, noteId, input);
    logger.info('Note updated', { noteId });

    return note;
  }

  async deleteNote(userId: string, noteId: string): Promise<void> {
    logger.info('Deleting note', { userId, noteId });

    await this.repository.delete(userId, noteId);
    logger.info('Note deleted', { noteId });
  }
}