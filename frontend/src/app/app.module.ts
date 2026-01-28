import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { FormsModule } from '@angular/forms';
import { HttpClientModule } from '@angular/common/http';
import { RouterModule, Routes } from '@angular/router';

import { AppComponent } from './app.component';
import { GalleryComponent } from './components/gallery/gallery.component';
import { PlayerComponent } from './components/player/player.component';
import { PaginationComponent } from './components/pagination/pagination.component';

const routes: Routes = [
  { path: '', component: GalleryComponent }, // default view = gallery
  { path: 'player/:id', component: PlayerComponent } // player view by file id
];

@NgModule({
  declarations: [
    AppComponent,
    GalleryComponent,
    PlayerComponent,
    PaginationComponent   // <-- declare here
  ],
  imports: [
    BrowserModule,
    FormsModule,
    HttpClientModule,
    RouterModule.forRoot(routes) // enables navigation between Gallery & Player
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule {}
