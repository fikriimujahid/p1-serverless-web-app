'use client';

import React from 'react';
import Link from 'next/link';
import { useNotes } from '@/hooks/useNotes';
import { ProtectedRoute } from '@/components/ProtectedRoute';

function NotesPageContent() {
  const { notes, isLoading, error, deleteNote, isDeleting } = useNotes();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div
          className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
          role="status"
          aria-label="Loading notes"
        ></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded">
        Failed to load notes. Please try again.
      </div>
    );
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Your Notes</h1>
        <Link
          href="/notes/new"
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          + New Note
        </Link>
      </div>

      {!notes || notes.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500 mb-4">No notes yet</p>
          <Link
            href="/notes/new"
            className="text-blue-600 hover:underline"
          >
            Create your first note
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {notes.map((note) => (
            <div key={note.id} className="bg-white p-4 rounded-lg shadow">
              <Link href={`/notes/edit?id=${note.id}`}>
                <h3 className="text-lg font-semibold mb-2 hover:text-blue-600">
                  {note.title}
                </h3>
              </Link>
              <p className="text-gray-600 text-sm line-clamp-3 mb-3">
                {note.content}
              </p>
              <div className="flex gap-2">
                <Link
                  href={`/notes/edit?id=${note.id}`}
                  className="text-blue-600 hover:underline text-sm"
                >
                  Edit
                </Link>
                <button
                  onClick={() => deleteNote(note.id)}
                  disabled={isDeleting}
                  className="text-red-600 hover:underline text-sm disabled:opacity-50"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default function NotesPage() {
  return (
    <ProtectedRoute>
      <NotesPageContent />
    </ProtectedRoute>
  );
}