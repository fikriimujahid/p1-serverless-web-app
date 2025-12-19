import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import NotesPage from './page';
import * as useNotesHook from '@/hooks/useNotes';

// Mock the useNotes hook
vi.mock('@/hooks/useNotes', () => ({
  useNotes: vi.fn(),
}));

// Mock next/link
vi.mock('next/link', () => {
  return {
    default: ({ href, children }: any) => <a href={href}>{children}</a>,
  };
});

describe('NotesPage', () => {
  const mockNotes = [
    {
      id: '1',
      title: 'Test Note 1',
      content: 'This is test content 1',
      tags: [],
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    },
    {
      id: '2',
      title: 'Test Note 2',
      content: 'This is test content 2',
      tags: ['tag1', 'tag2'],
      createdAt: '2025-01-02T00:00:00Z',
      updatedAt: '2025-01-02T00:00:00Z',
    },
  ];

  const mockDeleteNote = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('displays loading spinner when loading', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: [], 
      isLoading: true,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    const spinner = screen.getByText((content, element) => {
      return element?.className?.includes('animate-spin') || false;
    });
    expect(spinner).toBeInTheDocument();
  });

  it('displays error message when error occurs', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: [],
      isLoading: false,
      error: new Error('Failed to load notes'),
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    expect(screen.getByText('Failed to load notes. Please try again.')).toBeInTheDocument();
  });

  it('displays empty state when no notes', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: [],
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    expect(screen.getByText('No notes yet')).toBeInTheDocument();
    expect(screen.getByText('Create your first note')).toBeInTheDocument();
  });

  it('displays list of notes', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: mockNotes,
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    expect(screen.getByText('Test Note 1')).toBeInTheDocument();
    expect(screen.getByText('Test Note 2')).toBeInTheDocument();
    expect(screen.getByText('This is test content 1')).toBeInTheDocument();
    expect(screen.getByText('This is test content 2')).toBeInTheDocument();
  });

  it('displays new note button', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: [],
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    const newNoteButton = screen.getByRole('link', { name: /new note/i });
    expect(newNoteButton).toBeInTheDocument();
    expect(newNoteButton).toHaveAttribute('href', '/notes/new');
  });

  it('displays edit and delete buttons for each note', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: mockNotes,
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    const editLinks = screen.getAllByRole('link', { name: /edit/i });
    const deleteButtons = screen.getAllByRole('button', { name: /delete/i });

    expect(editLinks).toHaveLength(2);
    expect(deleteButtons).toHaveLength(2);
  });

  it('calls deleteNote when delete button is clicked', async () => {
    const user = userEvent.setup();
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: mockNotes,
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    const deleteButtons = screen.getAllByRole('button', { name: /delete/i });

    await user.click(deleteButtons[0]);
    expect(mockDeleteNote).toHaveBeenCalledWith('1');
  });

  it('disables delete button when deleting', () => {
    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: mockNotes,
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: true,
    } as any);

    render(<NotesPage />);
    const deleteButtons = screen.getAllByRole('button', { name: /delete/i });

    deleteButtons.forEach((button) => {
      expect(button).toBeDisabled();
    });
  });

  it('truncates content preview to 3 lines', () => {
    const longContent =
      'This is a very long note content that should be truncated to three lines. ' +
      'Line 2 of the content. ' +
      'Line 3 of the content. ' +
      'Line 4 that should be hidden.';

    const notesWithLongContent = [
      {
        ...mockNotes[0],
        content: longContent,
      },
    ];

    vi.mocked(useNotesHook.useNotes).mockReturnValue({
      notes: notesWithLongContent,
      isLoading: false,
      error: null,
      createNote: vi.fn(),
      isCreating: false,
      updateNote: vi.fn(),
      isUpdating: false,
      deleteNote: mockDeleteNote,
      isDeleting: false,
    } as any);

    render(<NotesPage />);
    const contentElement = screen.getByText((content, element) => {
      return element?.className === 'text-gray-600 text-sm line-clamp-3 mb-3';
    });

    expect(contentElement).toHaveClass('line-clamp-3');
  });
});
