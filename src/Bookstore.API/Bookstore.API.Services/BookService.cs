using Bookstore.API.Common.Models;
using Bookstore.API.Repository.Interfaces;
using Bookstore.API.Services.Interfaces;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Bookstore.API.Services
{
    public class BookService : IBookService
    {
        private readonly IBookRepository _bookRepository;
        private readonly ILogger<BookService> _logger;

        public BookService(IBookRepository bookRepository, ILogger<BookService> logger)
        {
            _bookRepository = bookRepository;
            _logger = logger;
        }

        public Task<List<Book>> GetAllBooks()
        {
            var books = _bookRepository.GetAllBooks();

            return books;
        }
    }
}
