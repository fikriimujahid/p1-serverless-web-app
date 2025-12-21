import NotePageClient from './NotePageClient';
import { ProtectedRoute } from '@/components/ProtectedRoute';

export const dynamic = 'force-static';

type PageProps = {
  searchParams?: { id?: string | string[] };
};

export default function EditNotePage({ searchParams }: PageProps) {
  const idParam = searchParams?.id;
  const id = Array.isArray(idParam) ? idParam[0] : idParam;

  return (
    <ProtectedRoute>
      <NotePageClient id={id} />
    </ProtectedRoute>
  );
}
