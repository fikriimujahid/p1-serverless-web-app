import client from './api-client';
import type { Note, CreateNoteRequest, UpdateNoteRequest } from '@/types/note';

export const notesApi = {
  listNotes: async (): Promise<Note[]> => {
    const response = await client.get<{ items: Note[]; nextToken?: string }>('/notes');
    return response.data.items;
  },

  getNote: async (id: string): Promise<Note> => {
    const response = await client.get<Note>(`/notes/${id}`);
    return response.data;
  },

  createNote: async (payload: CreateNoteRequest): Promise<Note> => {
    const response = await client.post<Note>('/notes', payload);
    return response.data;
  },

  updateNote: async (id: string, payload: UpdateNoteRequest): Promise<Note> => {
    const response = await client.put<Note>(`/notes/${id}`, payload);
    return response.data;
  },

  deleteNote: async (id: string): Promise<void> => {
    await client.delete(`/notes/${id}`);
  },
};