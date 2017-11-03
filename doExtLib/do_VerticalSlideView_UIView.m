//
//  do_VerticalSlideView_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_VerticalSlideView_UIView.h"

#import "doInvokeResult.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doJsonHelper.h"
#import "doIPage.h"
#import "doIApp.h"
#import "doISourceFS.h"
#import "doUIContainer.h"
#import "doServiceContainer.h"
#import "doILogEngine.h"
#import "doJsonHelper.h"

#define MIN_VALUE 0
@interface do_VerticalSlideView_UIView()<UIScrollViewDelegate>
@property (nonatomic , assign) int currentPage;
@end
@implementation do_VerticalSlideView_UIView
{
    id<doIListData> _dataArray;
    NSMutableArray *_pages;
    NSMutableDictionary *_moudles;
    int _positionPage;
    int _lastPage;
    BOOL _isDrag;
    
    BOOL _isAllCache;
}
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    _currentPage = 0;
    _pages = [NSMutableArray array];
    _moudles = [NSMutableDictionary dictionary];
    _lastPage = -99;
    _isAllCache = YES;
    self.scrollsToTop = NO;
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性,view-model(UIModel)类销毁时会递归调用<子view-model(UIModel)>的该方法，将上层的引用切断。所以如果self类有非原生扩展，需主动调用view-model(UIModel)的该方法。(App || Page)-->强引用-->view-model(UIModel)-->强引用-->view
    [(doModule*)_dataArray Dispose];
    self.delegate = nil;
    [self clearModules];
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改,如果添加了非原生的view需要主动调用该view的OnRedraw，递归完成布局。view(OnRedraw)<显示布局>-->调用-->view-model(UIModel)<OnRedraw>
    
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    [self initialization];
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
- (void)change_allowGesture:(NSString *)newValue
{
    //自己的代码实现
    self.scrollEnabled = [doJsonHelper GetBoolean:newValue :YES];
}
- (void)change_index:(NSString *)newValue
{
    //自己的代码实现
    if (!newValue || [newValue isEqualToString:@""]) {
        _currentPage = MIN_VALUE;
    }
    else
    {
        if (newValue.length > 5) {
            _currentPage = 9999;
        }
        else{
            _currentPage = [newValue intValue];
        }
    }
    if (_currentPage < 0 ) {
        _currentPage = 0;
    }
    [self resetView:[self getDisplayContent]];
    [self fireEvent:@(_currentPage)];
}
- (void)change_templates:(NSString *)newValue
{
    //自己的代码实现
    if (!newValue || [newValue isEqualToString:@""]) {
        return;
    }
    [_pages addObjectsFromArray:[newValue componentsSeparatedByString:@","]];
    [self clearModules];
    _moudles = [NSMutableDictionary dictionary];
}
#pragma mark -
#pragma mark - 同步异步方法的实现
//同步
- (void)bindItems:(NSArray *)parms
{
    NSDictionary * _dictParas = [parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine= [parms objectAtIndex:1];
    NSString* _address = [doJsonHelper GetOneValue:_dictParas :@"data"];
    
    @try {
        if (_address == nil || _address.length <= 0)
            [NSException raise:@"doVerticalSlideView" format:@"未指定相关的doVerticalSlideView data参数！",nil];
        id bindingModule = [doScriptEngineHelper ParseMultitonModule: _scriptEngine : _address];
        if (bindingModule == nil) [NSException raise:@"doVerticalSlideView" format:@"data参数无效！",nil];
        if([bindingModule conformsToProtocol:@protocol(doIListData)])
        {
            if(_dataArray!= bindingModule)
                _dataArray = bindingModule;
            if ([_dataArray GetCount] > 0) {
                [self refreshItems:parms];
            }
        }
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
    
}
- (void)refreshItems:(NSArray *)parms
{
    if ([_dataArray GetCount]<=0) {
        return;
    }
    if (_currentPage > [_dataArray GetCount] - 1)
    {
        _currentPage = [_dataArray GetCount] - 1;
    }
    [self resetView:[self getDisplayContent]];
}


#pragma mark - 私有方法
- (void)initialization{
    [self setDelegate:self];
    [self setPagingEnabled:YES];
    [self setShowsHorizontalScrollIndicator:NO];
    [self setShowsVerticalScrollIndicator:NO];
    
    self.decelerationRate = UIScrollViewDecelerationRateFast;
    self.canCancelContentTouches = NO;
}

- (int)currentPage
{
    int page = _currentPage;
    if (_currentPage < 0) {
        page = 0;
    }
    if ([_dataArray GetCount]>0) {
        if (_currentPage >= [_dataArray GetCount]) {
            page = [_dataArray GetCount]-1;
        }
    }else
        page = 0;
    
    return page;
}

//重新设置view
- (void)resetView:(NSArray *)a
{
    if ([_dataArray GetCount]<=0) {
        return;
    }
    CGFloat width = CGRectGetWidth(self.frame);
    CGFloat height = CGRectGetHeight(self.frame);
    [self setContentSize:CGSizeMake(width, height*[_dataArray GetCount])];
    _positionPage = 0;
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    for (int i = 0;i<a.count;i++) {
        int tmp = [[a objectAtIndex:i] intValue];
        UIView *view = [self getPage:[self getValideNum:tmp]];
        if (view) {
            CGFloat x = 0;
            x = (_positionPage+tmp)*height;
            view.frame = CGRectMake(0, x, width, height);
            [self addSubview:view];
        }
    }
    _positionPage += [[a objectAtIndex:[a indexOfObject:@(_currentPage)]] intValue];
    [self setContentOffset:CGPointMake(0, (_positionPage *height)) animated:NO];
}
//得到正确的索引
- (int)getValideNum:(int)num
{
    if (num < MIN_VALUE || num >= [_dataArray GetCount]) {
        return -1;
    }
    return num;
}
//得到view
- (UIView *)getPage:(int)num
{
    if (num < MIN_VALUE || num >= [_dataArray GetCount]) {
        return nil;
    }
    NSDictionary *dict = [_dataArray GetData:num];
    int num1 = [[dict objectForKey:@"template"] intValue];
    if (num1 < MIN_VALUE || num1 >= [_dataArray GetCount]) {
        return nil;
    }
    if (num1 >= _pages.count) {
        num1 = (int)(_pages.count - 1);
    }
    UIView *v = [self getAllCacheView:num1 index:num :dict];
    
    return v;
}

- (UIView *)getAllCacheView:(int)num1 index:(int)num :(NSDictionary *)dict
{
    
    NSString* fileName = [_pages objectAtIndex:num1];
    doSourceFile *source = [[[_model.CurrentPage CurrentApp] SourceFS] GetSourceByFileName:fileName];
    id<doIPage> pageModel = _model.CurrentPage;
    UIView *view;
    NSString *modelKey = [@(num) stringValue];
    doUIModule* module = [_moudles objectForKey:modelKey];
    if (!module) {
        doUIContainer *container = [[doUIContainer alloc] init:pageModel];
        [container LoadFromFile:source:nil:nil];
        module = container.RootView;
        [container LoadDefalutScriptFile:fileName];
        
        view = (UIView*)(((doUIModule*)module).CurrentUIModuleView);
        if (!view) {
            NSString *reason = [NSString stringWithFormat:@"模板%@错误",fileName];
            NSException *ex = [[NSException alloc]initWithName:@"do_VerticalSlideView" reason:reason userInfo:nil];
            [[doServiceContainer Instance].LogEngine WriteError:ex :@"do_VerticalSlideView"];
            return nil;
        }
        id<doIUIModuleView> modelView =((doUIModule*) module).CurrentUIModuleView;
        [modelView OnRedraw];
        [module SetModelData:dict];
    }
    else
    {
        view = (UIView*)(((doUIModule*)module).CurrentUIModuleView);
        id<doIUIModuleView> modelView =((doUIModule*) module).CurrentUIModuleView;
        [modelView OnRedraw];
        [module SetModelData:dict];

    }
    [_moudles setObject:module forKey:modelKey];
    
    return view;
}

- (void)clearModules
{
    [_moudles.allValues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [(doUIModule *)obj Dispose];
    }];
    [_moudles removeAllObjects];
    _moudles = nil;
}
- (NSArray *)getDisplayContent
{
    NSInteger c = [_dataArray GetCount]>3?3:[_dataArray GetCount];
    NSMutableArray *a = [NSMutableArray array];
    if (_currentPage == MIN_VALUE) {
        for (NSInteger i =0;i<c;i++) {
            [a addObject:@(i)];
        }
    }
    else if (_currentPage == [_dataArray GetCount]-1){
        for (NSInteger i = [_dataArray GetCount]-1;i>=0;i--) {
            [a addObject:@(i)];
            if (a.count>=3) {
                break;
            }
        }
        a = [NSMutableArray arrayWithArray:[[a reverseObjectEnumerator] allObjects]];
    }
    if (_currentPage>MIN_VALUE && _currentPage<[_dataArray GetCount]-1) {
        a = [NSMutableArray arrayWithObjects: @(_currentPage-1),@(_currentPage),@(_currentPage+1), nil];
    }
    
    if (c<3) {
        [self setContentSize:CGSizeMake(self.frame.size.width, self.frame.size.height * c)];
        self.contentOffset = CGPointMake(self.frame.size.width*abs(self.currentPage), 0);
    }
    return a;
}

- (void)prepareReuseView:(int)direction
{
    if (direction == 0) {
        return;
    }
    CGFloat pageWidth = CGRectGetWidth(self.frame);
    CGFloat pageHeight = CGRectGetHeight(self.frame);
    
    for (UIView *obj in self.subviews) {
        CGFloat y = CGRectGetMinY(obj.frame);
        CGFloat offset = y-_positionPage*pageHeight;
        if (fabs(offset/pageHeight) >= 1.9) {
            if ([self getValideNum:(int)(_currentPage+direction)]<0) {
                break;
            }
            [obj removeFromSuperview];
            
            UIView *v = [self getPage:[self getValideNum:[self genetatePrePage:direction :(int)(_currentPage+direction)]]];
            if (!v) {
                break;
            }
            v.frame = CGRectMake(0,(_positionPage+direction)*pageHeight, pageWidth, pageHeight);
            [self addSubview:v];
            
            break;
        }
    }
    _currentPage = [self genetatePrePage:direction :_currentPage];
}

- (int)genetatePrePage:(BOOL)isRight  :(int)page
{
    
    if (page < MIN_VALUE) {
        page = 0;
    }else if(page > [_dataArray GetCount]-1){
        page = [_dataArray GetCount]-1;
    }
    return page;
}

- (void)fireEvent:(NSNumber *)index
{
    doInvokeResult *invokeResult = [[doInvokeResult alloc]init];
    if (_lastPage == _currentPage) {
        return;
    }
    [_model SetPropertyValue:@"index" :[index stringValue]];
    [invokeResult SetResultInteger:[index intValue]];
    [_model.EventCenter FireEvent:@"indexChanged":invokeResult];
    
    _lastPage = _currentPage;
}
#pragma mark- scrollView的代理方法
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _isDrag = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_isDrag) {
        return;
    }
    CGFloat pageHeight = CGRectGetHeight(self.frame);
    int page = (fabs(scrollView.contentOffset.y)/pageHeight)+.5;
    if (page == [_dataArray GetCount]) {
        return;
    }
    if (page!=_positionPage) {
        int direction = 0;
        if (page>_positionPage) {
            direction = 1;
            ++_currentPage;
        }else if(page<_positionPage){
            direction = -1;
            --_currentPage;
        }
        _positionPage = page;
        [self prepareReuseView:direction];
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self fireEvent:@(_currentPage)];
}
#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}

@end
