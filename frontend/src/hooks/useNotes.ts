'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { notesApi } from '@/lib/notes-api';
import { useAuth } from '@/lib/auth';
import type { CreateNoteRequest, UpdateNoteRequest } from '@/types/note';

export function useNotes() {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  const { data: notes = [], isLoading, error } = useQuery({
    queryKey: ['notes', user?.userId],
    queryFn: () => notesApi.listNotes(),
    staleTime: 60 * 1000, // 1 minute
    enabled: !!user?.userId,
  });

  const createMutation = useMutation({
    mutationFn: (payload: CreateNoteRequest) => notesApi.createNote(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notes', user?.userId] });
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: UpdateNoteRequest }) =>
      notesApi.updateNote(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notes', user?.userId] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => notesApi.deleteNote(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notes', user?.userId] });
    },
  });

  return {
    notes,
    isLoading,
    error,
    createNote: createMutation.mutateAsync,
    isCreating: createMutation.isPending,
    updateNote: updateMutation.mutateAsync,
    isUpdating: updateMutation.isPending,
    deleteNote: deleteMutation.mutateAsync,
    isDeleting: deleteMutation.isPending,
  };
}

export function useNote(id: string) {
  const { user } = useAuth();
  
  const { data: note, isLoading, error } = useQuery({
    queryKey: ['notes', user?.userId, id],
    queryFn: () => notesApi.getNote(id),
    staleTime: 60 * 1000,
    enabled: !!user?.userId && !!id,
  });

  return { note, isLoading, error };
}