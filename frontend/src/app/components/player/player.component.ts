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

  currentIndex = 0;
  newTag = '';
  safeMediaUrl!: SafeResourceUrl;
  autoPlayNext = true;
  
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

    switch(event.key) {
      case 'Escape':
        this.closePlayer();
        break;
      case 'ArrowRight':
        if (event.shiftKey) {
          this.next();
        } else {
          this.seekForward();
        }
        event.preventDefault();
        break;
      case 'ArrowLeft':
        if (event.shiftKey) {
          this.prev();
        } else {
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
}
