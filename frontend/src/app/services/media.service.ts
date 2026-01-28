import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface MediaFile {
  id: number;
  filePath: string;
  album: string;
  type: string; // 'image', 'music', 'video', 'pdf', etc.
  thumbnailPath: string;
  duration?: number;
  resolution?: string;
  fileSize?: number;
  fileSizeFormatted?: string;
  createdAt?: string;
  tags?: string[];
  isFavorite?: number; // 0 or 1
}

@Injectable({ providedIn: 'root' })
export class MediaService {
  private API_URL = environment.apiUrl;

  constructor(private http: HttpClient) {}

  getAlbums(page: number = 1, limit: number = 50): Observable<any> {
    return this.http.get<string[]>(`${this.API_URL}/albums?page=${page}&limit=${limit}`);
  }

  getFiles(album?: string, page: number = 1, limit: number = 50, type?: string, sortBy?: string, sortOrder?: string): Observable<any> {
    let url = `${this.API_URL}/files?page=${page}&limit=${limit}`
    if (album) url += `&album=${album}`;
    if (type) url += `&type=${type}`;
    if (sortBy) url += `&sortBy=${sortBy}`;
    if (sortOrder) url += `&sortOrder=${sortOrder}`;
    return this.http.get<MediaFile[]>(url);
  }

  search(q: string): Observable<any> {
    return this.http.get<any>(`${this.API_URL}/search?q=${q}`);
  }

  getMediaUrl(file: MediaFile): string {
    return `${this.API_URL}/media/${file.id}`;
  }

  getFileById(id: number) {
    return this.http.get<MediaFile>(`${this.API_URL}/files/${id}`);
  }

  getThumbnail(file: MediaFile): string {
    return `${this.API_URL}/thumbnails/${file.thumbnailPath}`;
  }

  addTag(fileId: number, name: string): Observable<any> {
    return this.http.post(`${this.API_URL}/files/${fileId}/tags`, { name });
  }

  deleteTag(fileId: number, tagName: string): Observable<any> {
    return this.http.delete(`${this.API_URL}/files/${fileId}/tags/${encodeURIComponent(tagName)}`);
  }

  toggleFavorite(fileId: number): Observable<any> {
    return this.http.post(`${this.API_URL}/files/${fileId}/favorite`, {});
  }

  getFavorites(page: number = 1, limit: number = 50): Observable<any> {
    return this.http.get(`${this.API_URL}/favorites?page=${page}&limit=${limit}`);
  }

  getAllTags(): Observable<any> {
    return this.http.get(`${this.API_URL}/tags`);
  }

}
