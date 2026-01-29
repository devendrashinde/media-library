import { Component, Input, Output, EventEmitter, OnInit, OnDestroy, HostListener, ViewChild, ElementRef } from '@angular/core';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { MediaService, MediaFile } from '../../services/media.service';
import { Subject } from 'rxjs';
import { takeUntil, catchError } from 'rxjs/operators';
import { of } from 'rxjs';

@Component({
  selector: 'app-player',
  templateUrl: './player.component.html',
  styleUrls: ['./player.component.css']
})
export class PlayerComponent implements OnInit, OnDestroy {
  @Input() currentFile!: MediaFile;
  @Input() playlist: MediaFile[] = [];  
  @Output() close = new EventEmitter<void>();
  
  @ViewChild('videoPlayer') videoPlayer?: ElementRef<HTMLVideoElement>;
  @ViewChild('audioPlayer') audioPlayer?: ElementRef<HTMLAudioElement>;
  @ViewChild('imagePlayer') imagePlayer?: ElementRef<HTMLImageElement>;

  currentIndex = 0;
  newTag = '';
  safeMediaUrl!: SafeResourceUrl;
  autoPlayNext = true;
  
  // Image zoom, rotate, and pan
  imageZoom = 1;
  imageRotation = 0;
  panX = 0;
  panY = 0;
  isDragging = false;
  dragStartX = 0;
  dragStartY = 0;
  
  private destroy$ = new Subject<void>();

  constructor(public mediaService: MediaService, private sanitizer: DomSanitizer) {}

  ngOnInit() {
    if (this.playlist && this.currentFile) {
      this.currentIndex = this.playlist.findIndex(f => f.id === this.currentFile.id);
    }
    this.updateSafeUrl();
  }

  @HostListener('window:keydown', ['$event'])
  handleKeyboard(event: KeyboardEvent) {
    const target = event.target as HTMLElement;
    // Don't trigger if typing in input
    if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
      return;
    }

    // Handle image-specific shortcuts
    if (this.isMedia('image')) {
      if (event.ctrlKey || event.metaKey) {
        if (event.key === '+' || event.key === '=') {
          this.zoomIn();
          event.preventDefault();
          return;
        } else if (event.key === '-') {
          this.zoomOut();
          event.preventDefault();
          return;
        } else if (event.key === '0') {
          this.resetZoom();
          event.preventDefault();
          return;
        }
      }
      
      // For images, left/right without shift rotates instead of navigation
      if (!event.shiftKey && !event.ctrlKey && !event.metaKey) {
        if (event.key === 'ArrowRight') {
          this.rotateRight();
          event.preventDefault();
          return;
        } else if (event.key === 'ArrowLeft') {
          this.rotateLeft();
          event.preventDefault();
          return;
        }
      }
    }

    switch(event.key) {
      case 'Escape':
        this.closePlayer();
        break;
      case 'ArrowRight':
        if (event.shiftKey) {
          this.next();
        } else if (!this.isMedia('image')) {
          this.seekForward();
        }
        event.preventDefault();
        break;
      case 'ArrowLeft':
        if (event.shiftKey) {
          this.prev();
        } else if (!this.isMedia('image')) {
          this.seekBackward();
        }
        event.preventDefault();
        break;
      case 'ArrowUp':
        this.volumeUp();
        event.preventDefault();
        break;
      case 'ArrowDown':
        this.volumeDown();
        event.preventDefault();
        break;
      case ' ':
        this.togglePlayPause();
        event.preventDefault();
        break;
      case 'f':
      case 'F':
        this.toggleFullscreen();
        break;
    }
  }

  seekForward() {
    const media = this.getMediaElement();
    if (media) media.currentTime = Math.min(media.currentTime + 10, media.duration);
  }

  seekBackward() {
    const media = this.getMediaElement();
    if (media) media.currentTime = Math.max(media.currentTime - 10, 0);
  }

  volumeUp() {
    const media = this.getMediaElement();
    if (media) media.volume = Math.min(media.volume + 0.1, 1);
  }

  volumeDown() {
    const media = this.getMediaElement();
    if (media) media.volume = Math.max(media.volume - 0.1, 0);
  }

  togglePlayPause() {
    const media = this.getMediaElement();
    if (media) {
      if (media.paused) {
        media.play();
      } else {
        media.pause();
      }
    }
  }

  toggleFullscreen() {
    const media = this.getMediaElement();
    if (media && document.fullscreenEnabled) {
      if (!document.fullscreenElement) {
        media.requestFullscreen();
      } else {
        document.exitFullscreen();
      }
    }
  }

  getMediaElement(): HTMLVideoElement | HTMLAudioElement | null {
    if (this.videoPlayer) return this.videoPlayer.nativeElement;
    if (this.audioPlayer) return this.audioPlayer.nativeElement;
    return null;
  }

  updateSafeUrl() {
    const rawUrl = this.mediaService.getMediaUrl(this.current);
    this.safeMediaUrl = this.sanitizer.bypassSecurityTrustResourceUrl(rawUrl);
  }

  get mediaUrl(): string {
    return this.mediaService.getMediaUrl(this.playlist[this.currentIndex]);
  }

  get current(): MediaFile {
    return this.playlist[this.currentIndex];
  }

  next() {
    if (this.currentIndex < this.playlist.length - 1) {
      this.currentIndex++;
      this.updateSafeUrl();
    }
  }

  prev() {
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.updateSafeUrl();
    }
  }

  selectFromPlaylist(index: number) {
    this.currentIndex = index;
    this.updateSafeUrl();
  }

  onEnded() {
    if (this.autoPlayNext) {
      this.next();
    }
  }

  toggleAutoPlay() {
    this.autoPlayNext = !this.autoPlayNext;
  }

  closePlayer() {
    this.close.emit();
  }

  isMedia(type: string): boolean {
    return this.current.type === type;
  }

  hasPlaylist(): boolean {
    const mediaType = this.currentFile.type;
    return this.playlist.filter(f => f.type === mediaType).length > 1;
  }

  getFileName(file: MediaFile): string {
    if (!file?.filePath) return 'Unknown';
    const parts = file.filePath.split(/[\\/]/);
    return parts[parts.length - 1] || file.filePath;
  }

  addTag() {
    if (!this.newTag.trim()) return;
    const tag = this.newTag.trim();
    this.mediaService.addTag(this.current.id, tag)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          console.error('Failed to add tag:', err);
          return of(null);
        })
      )
      .subscribe(res => {
        if (res) {
          if (!this.current.tags) this.current.tags = [];
          this.current.tags.push(tag);
          this.newTag = '';
        }
      });
  }

  removeTag(tagName: string) {
    this.mediaService.deleteTag(this.current.id, tagName)
      .pipe(
        takeUntil(this.destroy$),
        catchError(err => {
          console.error('Failed to remove tag:', err);
          return of(null);
        })
      )
      .subscribe(res => {
        if (res && this.current.tags) {
          this.current.tags = this.current.tags.filter(t => t !== tagName);
        }
      });
  }

  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }

  // Image zoom and rotate methods
  zoomIn() {
    this.imageZoom = Math.min(this.imageZoom + 0.25, 4);
  }

  zoomOut() {
    this.imageZoom = Math.max(this.imageZoom - 0.25, 0.5);
  }

  resetZoom() {
    this.imageZoom = 1;
    this.imageRotation = 0;
    this.panX = 0;
    this.panY = 0;
  }

  rotateLeft() {
    this.imageRotation = (this.imageRotation - 90) % 360;
  }

  rotateRight() {
    this.imageRotation = (this.imageRotation + 90) % 360;
  }

  getImageTransform(): string {
    return `translate(${this.panX}px, ${this.panY}px) scale(${this.imageZoom}) rotate(${this.imageRotation}deg)`;
  }

  onImageWheel(event: WheelEvent) {
    if (event.ctrlKey) {
      event.preventDefault();
      if (event.deltaY < 0) {
        this.zoomIn();
      } else {
        this.zoomOut();
      }
    }
  }

  onImageMouseDown(event: MouseEvent) {
    if (this.imageZoom > 1) {
      this.isDragging = true;
      this.dragStartX = event.clientX - this.panX;
      this.dragStartY = event.clientY - this.panY;
      event.preventDefault();
    }
  }

  @HostListener('window:mousemove', ['$event'])
  onImageMouseMove(event: MouseEvent) {
    if (!this.isDragging || this.imageZoom <= 1 || !this.imagePlayer) {
      return;
    }

    const deltaX = event.clientX - this.dragStartX;
    const deltaY = event.clientY - this.dragStartY;

    // Get image and container dimensions
    const img = this.imagePlayer.nativeElement;
    const imgWidth = img.naturalWidth || img.width;
    const imgHeight = img.naturalHeight || img.height;
    const containerWidth = img.parentElement?.offsetWidth || window.innerWidth;
    const containerHeight = img.parentElement?.offsetHeight || window.innerHeight;

    // Calculate max pan based on zoomed image size
    // The zoomed image is larger, so we can pan to show all of it
    const scaledWidth = imgWidth * this.imageZoom;
    const scaledHeight = imgHeight * this.imageZoom;

    // Maximum pan is half the difference between zoomed and container size
    const maxPanX = Math.max(0, (scaledWidth - containerWidth) / 2);
    const maxPanY = Math.max(0, (scaledHeight - containerHeight) / 2);

    // Clamp pan values to allow full view of zoomed image
    this.panX = Math.max(-maxPanX, Math.min(maxPanX, deltaX));
    this.panY = Math.max(-maxPanY, Math.min(maxPanY, deltaY));
  }

  @HostListener('window:mouseup')
  onImageMouseUp() {
    this.isDragging = false;
  }}