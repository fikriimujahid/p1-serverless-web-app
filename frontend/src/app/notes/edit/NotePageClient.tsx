"use client";

import React, { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useNote, useNotes } from '@/hooks/useNotes';

type Props = {
  id?: string;
};

export default function NotePageClient({ id }: Props) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const noteId = id ?? searchParams.get('id') ?? '';

  const { note, isLoading, error } = useNote(noteId);
  const { updateNote, isUpdating } = useNotes();
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [editError, setEditError] = useState('');

  useEffect(() => {
    if (note) {
      setTitle(note.title);
      setContent(note.content);
    }
  }, [note]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setEditError('');

    if (!noteId) {
      setEditError('Missing note id');
      return;
    }

    try {
      await updateNote({ id: noteId, payload: { title, content } });
      router.push('/notes');
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to update note';
      setEditError(message);
    }
  };

  if (!noteId) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded">
        Missing note id. Please return to the notes list.
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" role="status" aria-label="Loading note"></div>
      </div>
    );
  }

  if (error || !note) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded">
        Failed to load note. Please try again.
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Edit Note</h1>

      {editError && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-700 rounded">
          {editError}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Content</label>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={10}
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div className="flex gap-4">
          <button
            type="submit"
            disabled={isUpdating}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isUpdating ? 'Saving...' : 'Save Changes'}
          </button>
          <button
            type="button"
            onClick={() => router.push('/notes')}
            className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
