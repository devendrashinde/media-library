import { Component, EventEmitter, Input, Output } from '@angular/core';

@Component({
  selector: 'app-pagination',
  templateUrl: './pagination.component.html',
  styleUrls: ['./pagination.component.css']
})
export class PaginationComponent {
  @Input() total: number = 0;     // total items
  @Input() page: number = 1;      // current page
  @Input() limit: number = 50;    // items per page

  @Output() pageChange = new EventEmitter<number>();

  get totalPages(): number {
    return Math.ceil(this.total / this.limit);
  }

  prev() {
    if (this.page > 1) {
      this.pageChange.emit(this.page - 1);
    }
  }

  next() {
    if (this.page < this.totalPages) {
      this.pageChange.emit(this.page + 1);
    }
  }
}
