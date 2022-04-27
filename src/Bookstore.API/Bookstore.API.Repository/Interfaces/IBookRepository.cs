using Bookstore.API.Common.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Bookstore.API.Repository.Interfaces
{
    public interface IBookRepository
    {
        Task<List<Book>> GetAllBooks();
    }
}
