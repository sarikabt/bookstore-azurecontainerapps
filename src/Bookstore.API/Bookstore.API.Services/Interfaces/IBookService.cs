using Bookstore.API.Common.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Bookstore.API.Services.Interfaces
{
    public interface IBookService
    {
        Task<List<Book>> GetAllBooks();
    }
}
