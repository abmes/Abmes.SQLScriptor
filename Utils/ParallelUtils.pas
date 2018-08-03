unit ParallelUtils;

interface

uses
  OtlTask, OtlTaskControl, SysUtils;

procedure WaitForAllTasks(const ATaskGroup: IOmniTaskGroup);

type
  TTaskThread = (ttNewThread, ttSameThread);

procedure RunTask(ATaskThread: TTaskThread; AProc: TProc);

implementation

procedure WaitForAllTasks(const ATaskGroup: IOmniTaskGroup);
var
  Task: IOmniTaskControl;
begin
  Assert(Assigned(ATaskGroup));

  for Task in ATaskGroup do
    Task.WaitFor(INFINITE);
end;

procedure RunTask(ATaskThread: TTaskThread; AProc: TProc);
begin
  if (ATaskThread = ttSameThread) then
    AProc
  else
    CreateTask(
      procedure (const task: IOmniTask)
      begin
        AProc;
      end
    ).Run;
end;

end.
