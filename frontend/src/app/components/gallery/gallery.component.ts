import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { MediaService, MediaFile } from '../../services/media.service';
import { Router } from '@angular/router';
import { Subject } from 'rxjs';
import { takeUntil, catchError } from 'rxjs/operators';
import { of } from 'rxjs';

@Component({
  selector: 'app-gallery',
  templateUrl: './gallery.component.html',
  styleUrls: ['./gallery.component.css']
})
export class GalleryComponent implements OnInit, OnDestroy {
  albums: string[] = [];
  selectedAlbum: string = '';
  files: MediaFile[] = [];
  playlistFiles: MediaFile[] = [];
  selectedIndex: number | null = null;
  query: string = '';
  albumPage = 1;
  filePage = 1;
  limit = 50;
  Math = Math;

  totalAlbums = 0;
  totalFiles = 0;
  newTag: string = '';
  showPlayer: boolean = false;
  showGoTop = false;
  
  loading = false;
  error: string | null = null;
  
  // New features
  typeFilter: string = ''; // '', 'image', 'video', 'music', 'pdf'
  sortBy: string = 'createdAt'; // 'createdAt', 'filePath', 'fileSize'
  sortOrder: string = 'desc'; // 'asc', 'desc'
  gridSize: string = 'medium'; // 'small', 'medium', 'large'
  darkMode: boolean = false;
  showFavoritesOnly: boolean = false;
  allTags: string[] = [];
  tagInput: string = '';
  showTagSuggestions: boolean = false;
  mobileMenuOpen: boolean = false;
  toolbarOpen: boolean = true;
  albumSearchQuery: string = '';
  
  private destroy$ = new Subject<void>();

  constructor(public mediaService: MediaService, private router: Router) {}

  ngOnInit(): void {
    this.loadTheme();
    this.loadGridSize();
    this.loadAlbums();
    this.loadAllTags();
  }

  loadTheme() {
    const savedTheme = localStorage.getItem('darkMode');
    this.darkMode = savedTheme === 'true';
    this.applyTheme();
  }

  loadGridSize() {
    const savedSize = localStorage.getItem('gridSize');
    if (savedSize) this.gridSize = savedSize;
  }

  applyTheme() {
    if (this.darkMode) {
      document.body.classList.add('dark-mode');
    } else {
      document.body.classList.remove('dark-mode');
    }
  }

  toggleDarkMode() {
    this.darkMode = !this.darkMode;
    localStorage.setItem('darkMode', this.darkMode.toString());
    this.applyTheme();
  }

  setGridSize(size: string) {
    this.gridSize = size;
    localStorage.setItem('gridSize', size);
  }

  toggleMobileMenu() {
    this.mobileMenuOpen = !this.mobileMenuOpen;
  }

  closeMobileMenu() {
    this.mobileMenuOpen = false;
  }

  toggleToolbar() {
    this.toolbarOpen = !this.toolbarOpen;
  }

  clearSearch() {
    this.query = '';
    this.search();
  }

  clearAlbumSearch() {
    this.albumSearchQuery = '';
  }

  loadAllTags() {
    this.mediaService.getAllTags()
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          console.error('Failed to load tags:', err);
          return of({ tags: [] });
        })
      )
      .subscribe(res => {
        this.allTags = res.tags || [];
      });
  }

  @HostListener('window:keydown', ['$event'])
  handleKeyboardEvent(event: KeyboardEvent) {
    if (this.showPlayer) {
      // Player is open, let player component handle it
      return;
    }
    
    // ESC to clear search
    if (event.key === 'Escape') {
      this.query = '';
      this.search();
    }
  }

  onFileScroll(event: any) {
    const scrollTop = event.target.scrollTop;
    this.showGoTop = scrollTop > 300;
  }

  scrollFilesToTop(element: HTMLElement) {
    if(!element) return;
    element.scrollTo({ top: 0, behavior: 'smooth' });
  }

  loadAlbums(page: number = 1) {
    this.loading = true;
    this.error = null;
    
    this.mediaService.getAlbums(page, this.limit)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          this.error = 'Failed to load albums';
          console.error(err);
          return of({ albums: [], total: 0, page: 1 });
        })
      )
      .subscribe(res => {
        this.albums = res.albums;
        this.totalAlbums = res.total;
        this.albumPage = res.page;
        this.loading = false;
      });
  }

  selectAlbum(album: string) {
    this.selectedAlbum = album;
    this.showFavoritesOnly = false;
    this.closeMobileMenu();
    this.loadFiles(album);
  }

  loadFiles(album?: string, page: number = 1) {
    this.loading = true;
    this.error = null;
    
    if (this.showFavoritesOnly) {
      this.loadFavorites(page);
      return;
    }
    
    this.mediaService.getFiles(album, page, this.limit, this.typeFilter, this.sortBy, this.sortOrder)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          this.error = 'Failed to load files';
          console.error(err);
          return of({ files: [], total: 0, page: 1 });
        })
      )
      .subscribe(res => {
        this.files = res.files;
        this.totalFiles = res.total;
        this.filePage = res.page;
        this.loading = false;
      });
  }

  loadFavorites(page: number = 1) {
    this.loading = true;
    this.error = null;
    
    this.mediaService.getFavorites(page, this.limit)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          this.error = 'Failed to load favorites';
          console.error(err);
          return of({ files: [], total: 0, page: 1 });
        })
      )
      .subscribe(res => {
        this.files = res.files;
        this.totalFiles = res.total;
        this.filePage = res.page;
        this.loading = false;
      });
  }

  toggleFavorites() {
    this.showFavoritesOnly = !this.showFavoritesOnly;
    this.filePage = 1;
    if (this.showFavoritesOnly) {
      this.loadFavorites();
    } else {
      this.loadFiles(this.selectedAlbum);
    }
  }

  toggleFavorite(file: MediaFile, event: Event) {
    event.stopPropagation();
    this.mediaService.toggleFavorite(file.id)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          console.error('Failed to toggle favorite:', err);
          return of(null);
        })
      )
      .subscribe(res => {
        if (res) {
          (file as any).isFavorite = res.isFavorite ? 1 : 0;
        }
      });
  }

  setTypeFilter(type: string) {
    this.typeFilter = type;
    this.filePage = 1;
    this.loadFiles(this.selectedAlbum);
  }

  setSortBy(field: string) {
    if (this.sortBy === field) {
      this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
    } else {
      this.sortBy = field;
      this.sortOrder = 'desc';
    }
    this.filePage = 1;
    this.loadFiles(this.selectedAlbum);
  }

  search() {
    this.filePage = 1; // Reset pagination
    if (this.query.trim() === '') {
      this.loadFiles(this.selectedAlbum);
    } else {
      this.loading = true;
      this.error = null;
      
      this.mediaService.search(this.query)
        .pipe(
          takeUntil(this.destroy$),
          catchError(err => {
            this.error = 'Search failed';
            console.error(err);
            return of({ files: [] });
          })
        )
        .subscribe(res => {
          this.files = res.files || [];
          this.totalFiles = this.files.length;
          this.loading = false;
        });
    }
  }

  thumbnail(file: MediaFile): string {
    return this.mediaService.getThumbnail(file);
  }

  fileName(file: MediaFile): string {
    if (!file?.filePath) return '';
    const parts = file.filePath.split(/[\\/]/);
    return parts[parts.length - 1] || file.filePath;
  }

  displayLabel(file: MediaFile): string {
    if (file?.tags && file.tags.length) {
      return file.tags.join(', ');
    }
    return this.fileName(file);
  }

  play(file: MediaFile) {  // <-- make sure this exists
    this.router.navigate(['/player', file.id]);
  }

  get totalAlbumPages(): number {
    return Math.ceil(this.totalAlbums / this.limit);
  }

  get totalFilePages(): number {
    return Math.ceil(this.totalFiles / this.limit);
  }

  addTag(file: MediaFile, tag: string) {
    if (!tag.trim()) return;

    this.mediaService.addTag(file.id, tag)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          console.error('Failed to add tag:', err);
          return of(null);
        })
      )
      .subscribe(res => {
        if (res) {
          if (!file.tags) file.tags = [];
          if (!file.tags.includes(res.tag.name)) {
            file.tags.push(res.tag.name);
          }
          this.tagInput = '';
          this.showTagSuggestions = false;
          this.loadAllTags(); // Refresh tags list
        }
      });
  }

  get filteredTags(): string[] {
    if (!this.tagInput.trim()) return [];
    const input = this.tagInput.toLowerCase();
    return this.allTags.filter(tag => 
      tag.toLowerCase().includes(input)
    ).slice(0, 5);
  }

  selectTag(tag: string, file?: MediaFile) {
    if (file) {
      this.addTag(file, tag);
    }
    this.tagInput = tag;
    this.showTagSuggestions = false;
  }

  get hasFiles(): boolean {
    return this.files && this.files.length > 0;
  }

  removeTag(file: MediaFile, tagName: string) {
    this.mediaService.deleteTag(file.id, tagName)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          console.error('Failed to remove tag:', err);
          return of(null);
        })
      )
      .subscribe(res => {
        if (res) {
          if (file.tags) {
            file.tags = file.tags.filter(t => t !== tagName);
          }
        }
      });
  }

  openPlayer(file: MediaFile) {
    this.selectedIndex = this.files.findIndex(f => f.id === file.id);      
    this.showPlayer = true;
    // Build playlist for all files of the same type
    const type = file.type;
    this.playlistFiles = this.files.filter(f => f.type === type);
  }

  closePlayer() {
    this.selectedIndex = null;
    this.showPlayer = false;
  }

  nextFile() {
    if (this.selectedIndex !== null && this.selectedIndex < this.files.length - 1) {
      this.selectedIndex++;
    }
  }

  prevFile() {
    if (this.selectedIndex !== null && this.selectedIndex > 0) {
      this.selectedIndex--;
    }
  }

  get selectedFile(): MediaFile | null {
    return this.selectedIndex !== null ? this.files[this.selectedIndex] : null;
  }

  get filteredAlbums(): string[] {
    if (!this.albumSearchQuery.trim()) {
      return this.albums;
    }
    const query = this.albumSearchQuery.toLowerCase();
    return this.albums.filter(album => 
      (album || 'Root').toLowerCase().includes(query)
    );
  }

  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }

}
