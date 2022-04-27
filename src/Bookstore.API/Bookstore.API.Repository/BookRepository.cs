using Bookstore.API.Common.Models;
using Bookstore.API.Repository.Interfaces;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Bookstore.API.Repository
{
    public class BookRepository : IBookRepository
    {
        private readonly CosmosClient _cosmosClient;
        private readonly Container _container;
        private readonly IConfiguration _configuration;
        private readonly ILogger<BookRepository> _logger;

        public BookRepository(CosmosClient cosmosClient, IConfiguration configuration, ILogger<BookRepository> logger)
        {
            _cosmosClient = cosmosClient;
            _configuration = configuration;
            _logger = logger;
            _container = _cosmosClient.GetContainer(_configuration["databasename"], _configuration["containername"]);
        }

        public async Task<List<Book>> GetAllBooks()
        {
            try
            {
                List<Book> books = new List<Book>();
                QueryDefinition queryDefinition = new QueryDefinition("SELECT * FROM c");
                FeedIterator<Book> feedIterator = _container.GetItemQueryIterator<Book>(queryDefinition);

                while (feedIterator.HasMoreResults)
                {
                    FeedResponse<Book> response = await feedIterator.ReadNextAsync();
                    books.AddRange(response);
                }

                return books;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex.Message);
                throw;
            }
        }
    }
}
