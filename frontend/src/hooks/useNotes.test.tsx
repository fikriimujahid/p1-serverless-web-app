import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import { useNotes, useNote } from './useNotes';
import * as notesApi from '@/lib/notes-api';
import * as authLib from '@/lib/auth';

// Mock modules
vi.mock('@/lib/notes-api');
vi.mock('@/lib/auth');

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

const createWrapper = () => {
  const testQueryClient = createTestQueryClient();

  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={testQueryClient}>{children}</QueryClientProvider>
  );
};

describe('useNotes hook', () => {
  const mockNotes = [
    {
      id: '1',
      title: 'Note 1',
      content: 'Content 1',
      tags: [],
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    },
  ];

  const mockUser = {
    email: 'test@example.com',
    userId: 'user-123',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(authLib.useAuth).mockReturnValue({
      isAuthenticated: true,
      user: mockUser,
      login: vi.fn(),
      signup: vi.fn(),
      confirmSignup: vi.fn(),
      resendConfirmation: vi.fn(),
      logout: vi.fn(),
      isLoading: false,
      idToken: 'token',
    } as any);
  });

  it('fetches and returns notes list', async () => {
    vi.mocked(notesApi.notesApi.listNotes).mockResolvedValue(mockNotes);

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    // Initially loading
    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.notes).toEqual(mockNotes);
  });

  it('handles error when fetching notes', async () => {
    const error = new Error('Failed to fetch notes');
    vi.mocked(notesApi.notesApi.listNotes).mockRejectedValue(error);

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.error).toBeDefined();
  });

  it('creates a new note', async () => {
    vi.mocked(notesApi.notesApi.listNotes).mockResolvedValue([]);
    vi.mocked(notesApi.notesApi.createNote).mockResolvedValue({
      id: '2',
      title: 'New Note',
      content: 'New Content',
      tags: [],
      createdAt: '2025-01-02T00:00:00Z',
      updatedAt: '2025-01-02T00:00:00Z',
    });

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    const createResult = await result.current.createNote({
      title: 'New Note',
      content: 'New Content',
    });

    expect(createResult.id).toBe('2');
    expect(notesApi.notesApi.createNote).toHaveBeenCalled();
  });

  it('updates an existing note', async () => {
    vi.mocked(notesApi.notesApi.listNotes).mockResolvedValue(mockNotes);
    vi.mocked(notesApi.notesApi.updateNote).mockResolvedValue({
      ...mockNotes[0],
      title: 'Updated Title',
    });

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    const updateResult = await result.current.updateNote({
      id: '1',
      payload: {
        title: 'Updated Title',
      },
    });

    expect(updateResult.title).toBe('Updated Title');
    expect(notesApi.notesApi.updateNote).toHaveBeenCalledWith('1', {
      title: 'Updated Title',
    });
  });

  it('deletes a note', async () => {
    vi.mocked(notesApi.notesApi.listNotes).mockResolvedValue(mockNotes);
    vi.mocked(notesApi.notesApi.deleteNote).mockResolvedValue(undefined);

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    await result.current.deleteNote('1');

    expect(notesApi.notesApi.deleteNote).toHaveBeenCalledWith('1');
  });

  it('returns loading state for mutations', async () => {
    vi.mocked(notesApi.notesApi.listNotes).mockResolvedValue([]);
    vi.mocked(notesApi.notesApi.createNote).mockResolvedValue({
      id: '2',
      title: 'New Note',
      content: 'New Content',
      tags: [],
      createdAt: '2025-01-02T00:00:00Z',
      updatedAt: '2025-01-02T00:00:00Z',
    });

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    expect(result.current.isCreating).toBe(false);
    expect(result.current.isUpdating).toBe(false);
    expect(result.current.isDeleting).toBe(false);
  });
});

describe('useNote hook', () => {
  const mockNote = {
    id: '1',
    title: 'Note 1',
    content: 'Content 1',
    tags: [],
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
  };

  const mockUser = {
    email: 'test@example.com',
    userId: 'user-123',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(authLib.useAuth).mockReturnValue({
      isAuthenticated: true,
      user: mockUser,
      login: vi.fn(),
      signup: vi.fn(),
      confirmSignup: vi.fn(),
      resendConfirmation: vi.fn(),
      logout: vi.fn(),
      isLoading: false,
      idToken: 'token',
    } as any);
  });

  it('fetches a single note by id', async () => {
    vi.mocked(notesApi.notesApi.getNote).mockResolvedValue(mockNote);

    const { result } = renderHook(() => useNote('1'), {
      wrapper: createWrapper(),
    });

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.note).toEqual(mockNote);
    expect(notesApi.notesApi.getNote).toHaveBeenCalledWith('1');
  });

  it('handles error when fetching a note', async () => {
    const error = new Error('Note not found');
    vi.mocked(notesApi.notesApi.getNote).mockRejectedValue(error);

    const { result } = renderHook(() => useNote('1'), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.error).toBeDefined();
  });

  it('disables query when user is not authenticated', () => {
    vi.mocked(authLib.useAuth).mockReturnValue({
      isAuthenticated: false,
      user: null,
      login: vi.fn(),
      signup: vi.fn(),
      confirmSignup: vi.fn(),
      resendConfirmation: vi.fn(),
      logout: vi.fn(),
      isLoading: false,
      idToken: null,
    } as any);

    vi.mocked(notesApi.notesApi.getNote).mockResolvedValue(mockNote);

    renderHook(() => useNote('1'), {
      wrapper: createWrapper(),
    });

    // Query should not be called when user is not authenticated
    expect(notesApi.notesApi.getNote).not.toHaveBeenCalled();
  });
});
