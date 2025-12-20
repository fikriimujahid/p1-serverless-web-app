import React, { ReactNode } from 'react';
import NotesLayoutClient from './NotesLayoutClient';

export default function NotesLayout({ children }: { children: ReactNode }) {
  return <NotesLayoutClient>{children}</NotesLayoutClient>;
}