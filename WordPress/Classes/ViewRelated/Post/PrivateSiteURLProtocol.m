#import "PrivateSiteURLProtocol.h"
#import "AccountService.h"
#import "ContextManager.h"
#import "WPAccount.h"
#import "Blog.h"

@interface PrivateSiteURLProtocol()
@property (nonatomic, strong) NSURLConnection *connection;
@end

static NSInteger regcount = 0;

@implementation PrivateSiteURLProtocol

+ (void)registerPrivateSiteURLProtocol
{
    @synchronized(self) {
        if (regcount == 0) {
            [NSURLProtocol registerClass:[self class]];
        }
        regcount++;
    }
}

+ (void)unregisterPrivateSiteURLProtocol
{
    @synchronized(self) {
        regcount--;
        if (regcount == 0) {
            [NSURLProtocol unregisterClass:[self class]];
        }
    }
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSString *token = [self bearerToken];
    NSString *authHeader = [request.allHTTPHeaderFields stringForKey:@"Authorization"];
    if (token && (!authHeader || [authHeader rangeOfString:@"Bearer"].location == NSNotFound) && [self requestGoesToWPComSite:request]) {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

+ (NSString *)bearerToken
{
    // Thread Safety: Make sure we're running on the Main Thread
    if ([NSThread isMainThread]) {
        NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
        AccountService *service         = [[AccountService alloc] initWithManagedObjectContext:context];
        return service.defaultWordPressComAccount.authToken;
    }

    // Otherwise, let's use a Derived Context
    __block NSString *authToken     = nil;
    NSManagedObjectContext *derived = [[ContextManager sharedInstance] newDerivedContext];
    AccountService *service         = [[AccountService alloc] initWithManagedObjectContext:derived];
    
    [derived performBlockAndWait:^{
        authToken = service.defaultWordPressComAccount.authToken;
    }];
    
    return authToken;
}

+ (BOOL)requestGoesToWPComSite:(NSURLRequest *)request
{
    if ([request.URL.scheme isEqualToString:@"https"] && [request.URL.host hasSuffix:@".wordpress.com"]) {
        return YES;
    }

    return NO;
}

- (void)startLoading
{
    NSMutableURLRequest *mRequest = [self.request mutableCopy];
    [mRequest addValue:[NSString stringWithFormat:@"Bearer %@", [[self class] bearerToken]] forHTTPHeaderField:@"Authorization"];
    self.connection = [NSURLConnection connectionWithRequest:mRequest delegate:self];
}

- (void)stopLoading
{
    [self.connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.client URLProtocolDidFinishLoading:self];
    self.connection = nil;
}

@end
