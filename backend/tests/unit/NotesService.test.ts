import { NotesService } from '../../src/services/NotesService';
import { NotesRepository } from '../../src/repositories/NotesRepository';
import { ValidationError, NotFoundError } from '../../src/types/errors';
import { Note } from '../../src/types/note';

jest.mock('../../src/repositories/NotesRepository');

describe('NotesService', () => {
  let service: NotesService;
  let mockRepositoryInstance: jest.Mocked<NotesRepository>;

  beforeEach(() => {
    jest.clearAllMocks();

    // Create a mock instance with all methods
    mockRepositoryInstance = {
      create: jest.fn(),
      list: jest.fn(),
      get: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    } as jest.Mocked<NotesRepository>;

    // Mock the constructor to return our mock instance
    (NotesRepository as jest.MockedClass<typeof NotesRepository>).mockImplementation(
      () => mockRepositoryInstance
    );

    service = new NotesService();
  });

  describe('createNote', () => {
    it('should successfully create a note with valid input', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Valid Title',
        content: 'Valid content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.create.mockResolvedValue(mockNote);

      const result = await service.createNote('user-123', {
        title: 'Valid Title',
        content: 'Valid content',
      });

      expect(result).toBeDefined();
      expect(result.title).toBe('Valid Title');
      expect(result.content).toBe('Valid content');
    });

    it('should throw ValidationError if title is empty', async () => {
      await expect(
        service.createNote('user-123', {
          title: '',
          content: 'Some content',
        })
      ).rejects.toThrow(ValidationError);
    });

    it('should throw ValidationError if title is whitespace only', async () => {
      await expect(
        service.createNote('user-123', {
          title: '   ',
          content: 'Some content',
        })
      ).rejects.toThrow('Title is required');
    });

    it('should throw ValidationError if title exceeds 120 characters', async () => {
      const longTitle = 'a'.repeat(121);
      await expect(
        service.createNote('user-123', {
          title: longTitle,
          content: 'Some content',
        })
      ).rejects.toThrow('Title must be 120 characters or less');
    });

    it('should throw ValidationError if content is empty', async () => {
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: '',
        })
      ).rejects.toThrow(ValidationError);
    });

    it('should throw ValidationError if content is whitespace only', async () => {
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: '   ',
        })
      ).rejects.toThrow('Content is required');
    });

    it('should throw ValidationError if content exceeds 10000 characters', async () => {
      const longContent = 'a'.repeat(10001);
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: longContent,
        })
      ).rejects.toThrow('Content must be 10000 characters or less');
    });

    it('should throw ValidationError if tags exceed 10', async () => {
      const manyTags = Array(11).fill('tag');
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: 'Valid content',
          tags: manyTags,
        })
      ).rejects.toThrow('Maximum 10 tags allowed');
    });

    it('should trim title and content', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Trimmed Title',
        content: 'Trimmed content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.create.mockResolvedValue(mockNote);

      const result = await service.createNote('user-123', {
        title: '  Trimmed Title  ',
        content: '  Trimmed content  ',
      });

      expect(result.title).toBe('Trimmed Title');
      expect(result.content).toBe('Trimmed content');
    });

    it('should include empty tags array when none provided', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Valid Title',
        content: 'Valid content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.create.mockResolvedValue(mockNote);

      const result = await service.createNote('user-123', {
        title: 'Valid Title',
        content: 'Valid content',
      });

      expect(result.tags).toEqual([]);
    });
  });

  describe('listNotes', () => {
    it('should return a list of notes', async () => {
      const mockNotes = {
        items: [
          {
            id: 'n_test1',
            title: 'Note 1',
            content: 'Content 1',
            tags: [],
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          },
        ],
        nextToken: null,
      };

      mockRepositoryInstance.list.mockResolvedValue(mockNotes);

      const result = await service.listNotes('user-123');

      expect(result).toBeDefined();
      expect(result.items).toHaveLength(1);
      expect(result.nextToken).toBeNull();
    });

    it('should support pagination with limit and nextToken', async () => {
      const mockNotes = {
        items: [],
        nextToken: 'token123',
      };

      mockRepositoryInstance.list.mockResolvedValue(mockNotes);

      const result = await service.listNotes('user-123', 10, 'token123');

      expect(result.nextToken).toBe('token123');
    });
  });

  describe('getNote', () => {
    it('should return a note by ID', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Test Note',
        content: 'Test content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.get.mockResolvedValue(mockNote);

      const result = await service.getNote('user-123', 'n_test123');

      expect(result).toBeDefined();
      expect(result.id).toBe('n_test123');
    });

    it('should throw NotFoundError if note does not exist', async () => {
      mockRepositoryInstance.get.mockRejectedValue(
        new NotFoundError('Note not found')
      );

      await expect(
        service.getNote('user-123', 'nonexistent')
      ).rejects.toThrow(NotFoundError);
    });
  });

  describe('updateNote', () => {
    it('should successfully update a note', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Updated Title',
        content: 'Updated content',
        tags: ['updated'],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.update.mockResolvedValue(mockNote);

      const result = await service.updateNote('user-123', 'n_test123', {
        title: 'Updated Title',
        content: 'Updated content',
        tags: ['updated'],
      });

      expect(result.title).toBe('Updated Title');
      expect(result.content).toBe('Updated content');
    });

    it('should throw ValidationError if updated title is empty', async () => {
      await expect(
        service.updateNote('user-123', 'n_test123', {
          title: '',
        })
      ).rejects.toThrow('Title cannot be empty');
    });

    it('should throw ValidationError if updated title exceeds 120 characters', async () => {
      const longTitle = 'a'.repeat(121);
      await expect(
        service.updateNote('user-123', 'n_test123', {
          title: longTitle,
        })
      ).rejects.toThrow('Title must be 120 characters or less');
    });

    it('should throw ValidationError if updated content exceeds 10000 characters', async () => {
      const longContent = 'a'.repeat(10001);
      await expect(
        service.updateNote('user-123', 'n_test123', {
          content: longContent,
        })
      ).rejects.toThrow('Content must be 10000 characters or less');
    });

    it('should throw ValidationError if updated tags exceed 10', async () => {
      const manyTags = Array(11).fill('tag');
      await expect(
        service.updateNote('user-123', 'n_test123', {
          tags: manyTags,
        })
      ).rejects.toThrow('Maximum 10 tags allowed');
    });

    it('should allow partial updates', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Updated Title',
        content: 'Original content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.update.mockResolvedValue(mockNote);

      const result = await service.updateNote('user-123', 'n_test123', {
        title: 'Updated Title',
      });

      expect(result.title).toBe('Updated Title');
    });
  });

  describe('deleteNote', () => {
    it('should successfully delete a note', async () => {
      mockRepositoryInstance.delete.mockResolvedValue(undefined);

      await service.deleteNote('user-123', 'n_test123');

      expect(mockRepositoryInstance.delete).toHaveBeenCalledWith(
        'user-123',
        'n_test123'
      );
    });
  });
});