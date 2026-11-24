using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

var config = new ConfigurationBuilder()
  .SetBasePath(@"E:\AquaRider\backend\Application.Api")
  .AddJsonFile("appsettings.json")
  .AddJsonFile("appsettings.Development.json", true)
  .Build();
var services = new ServiceCollection();
services.AddLogging();
services.AddSingleton<IConfiguration>(config);
services.AddDbContext<AppDbContext>(o => o.UseSqlServer(config.GetConnectionString("Default")));
services.AddIdentityCore<ApplicationUser>().AddRoles<IdentityRole>().AddEntityFrameworkStores<AppDbContext>().AddDefaultTokenProviders();
var sp = services.BuildServiceProvider();
var users = sp.GetRequiredService<UserManager<ApplicationUser>>();
var user = await users.FindByEmailAsync("infotechlab498@gmail.com");
Console.WriteLine($"found={user?.UserName} hash={(user?.PasswordHash?.Length)}");
Console.WriteLine($"check={await users.CheckPasswordAsync(user!, "info498@")}");
Console.WriteLine($"hasPwd={await users.HasPasswordAsync(user!)}");
