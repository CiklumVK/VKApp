//
//  FriendsTableDataSource.m
//  VKApplication
//
//  Created by Vasyl Vasylchenko on 16.01.16.
//  Copyright © 2016 Vasyl Vasylchenko. All rights reserved.
//

#import "FriendsTableDataSource.h"
#import "CustomCell.h"
#import "NSString+Extension.h"
#import "VKAPI.h"
#import "VKClient.h"
#import "VKFriendsModel.h"
#import "MTLJSONAdapterWithoutNil.h"
#import "CoreDataStack.h"
#import "FriendEntity.h"

@interface FriendsTableDataSource()<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property UITableView *theTableView;
@property NSMutableDictionary *friendsDictionary;
@property NSMutableArray *oldFriends;
@property VKClient *vkClient;
@end



@implementation FriendsTableDataSource


- (instancetype)initWithTableView:(UITableView *)tableView withSearchBar:(UISearchBar *)searchBar andUserID:(NSNumber *)userID{
    self = [super init];
    self.userID = userID;
    self.friendsDictionary = @{}.mutableCopy;
    self.theTableView = [UITableView new];
    self.vkClient = [VKClient new];
    [self configureTableView:tableView];
    [self loadFriendList];
    [self configureSearchBar:searchBar];
    
    return self;
}

- (void)configureSearchBar:(UISearchBar *)searchBar{
    searchBar.delegate = self;
}

- (void)configureTableView:(UITableView *)tableView{
    tableView.delegate = self;
    tableView.dataSource = self;
    [tableView registerNib:[UINib nibWithNibName:@"CustomCell" bundle:nil] forCellReuseIdentifier:@"FriendCell"];
    self.theTableView = tableView;
}

- (void)loadFriendList{

    [self.vkClient getFriendsListbyUesrID:self.userID withhResponse:^(NSArray *responseObject) {
        NSArray<VKFriendsModel *> *responsedArray = [MTLJSONAdapterWithoutNil modelsOfClass:[VKFriendsModel class] fromJSONArray:responseObject error:nil];
        
        [self.friendsDictionary setValue:responsedArray forKey:@"Friends"];
        self.oldFriends = [responsedArray mutableCopy];
        [self.theTableView reloadData];

    }];
        
    
    
}

#pragma mark - tableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return [self.friendsDictionary count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    return [[self.friendsDictionary allKeys] objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [self arrayWithSection:section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    CustomCell * cell = [tableView dequeueReusableCellWithIdentifier:@"FriendCell" forIndexPath:indexPath];
    [cell fillWithObject:[self arrayWithSection:indexPath.section][indexPath.row] atIndex:indexPath];
    return cell;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if ([self.delegate respondsToSelector:@selector(didSelectObject:atIndexPath:)]) {
        [self.delegate didSelectObject:[self arrayWithSection:indexPath.section][indexPath.row] atIndexPath:indexPath];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 30;
}



#pragma mark - searchBar

- (void)doSearch:(NSString *)searchText{
    [self.vkClient makeSearchWithText:searchText response:^(NSArray *responseObject) {
        NSArray *responsedArray = [MTLJSONAdapterWithoutNil modelsOfClass:[VKFriendsModel class] fromJSONArray:responseObject error:nil];
        NSArray *sortedArray = [self.oldFriends filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"firstName contains %@", searchText]];
        [self.friendsDictionary setValue:responsedArray forKey:@"Global search"];
        [self.friendsDictionary setValue:sortedArray forKey:@"Friends"];
        [self.theTableView reloadData];
    }];

}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
    if (searchText.length==0) {
        [self.friendsDictionary setValue:self.oldFriends forKey:@"Friends"];
        [self.friendsDictionary removeObjectForKey:@"Global search"];
        [self.theTableView reloadData];
    } else {
        [self doSearch:searchText];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar{
    searchBar.text = nil;
    [searchBar resignFirstResponder];
    [self.friendsDictionary setValue:self.oldFriends forKey:@"Friends"];
    [self.friendsDictionary removeObjectForKey:@"Global search"];
    [self.theTableView reloadData];
}

- (NSArray *)arrayWithSection:(NSInteger)section{
    NSString * str = [self.friendsDictionary allKeys][section];
    NSArray * a = [self.friendsDictionary valueForKey:str];
    return a;
}

# pragma mark - CoreData

- (NSArray *)fetchedArray{
    CoreDataStack *stack = [CoreDataStack new];
    NSManagedObjectContext *context= [stack managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"FriendEntity"
                                              inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
    NSError *error;
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];

    NSLog(@"%@ " , fetchedObjects );
    return fetchedObjects;
}

- (void)saveMYfriendsByResponsedArray:(NSArray *)responsedArray{
    
    for (VKFriendsModel *obj in responsedArray){
        CoreDataStack *coreDataStack = [CoreDataStack new];

    FriendEntity *friend = [NSEntityDescription insertNewObjectForEntityForName:@"FriendEntity" inManagedObjectContext:[coreDataStack managedObjectContext]];
    [friend setValue:obj.firstName forKey:@"fristName"];
//    friend.lastName = obj.lastName;
//    friend.userID = [NSString stringWithFormat:@"%@",obj.userId ];
//    friend.onlineValue = [NSString stringWithFormat:@"%@",obj.onlineValue];
//    friend.photoPath = obj.photo100;
    
        NSError *error = nil;
        if ([[coreDataStack managedObjectContext] save:&error] == NO) {
            NSAssert(NO, @"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
        }    }
}

- (void)deleteEntity{
    CoreDataStack *coreDataStack = [CoreDataStack new];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"FriendEntity"];
    NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    
    [coreDataStack.persistentStoreCoordinator executeRequest:delete withContext:coreDataStack.managedObjectContext error:nil];

}

# pragma mark - Internet test

- (BOOL)connected{
    NSURL *scriptUrl = [NSURL URLWithString:@"http://www.google.com/m"];
    NSData *data = [NSData dataWithContentsOfURL:scriptUrl];
    if (data)
        return YES;
    else
        return NO;
}


@end
