using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/onboarding")]
public sealed class OnboardingController : ControllerBase
{
    private readonly IOnboardingService _onboarding;

    public OnboardingController(IOnboardingService onboarding)
    {
        _onboarding = onboarding;
    }

    [HttpGet("overview")]
    public async Task<IActionResult> Overview(CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.OverviewAsync(cancellationToken));

    [HttpGet("steps")]
    public async Task<IActionResult> Steps(CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.StepsAsync(cancellationToken));

    [HttpGet("steps/{stepCode}")]
    public async Task<IActionResult> Step(string stepCode, CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.StepAsync(stepCode, cancellationToken));

    [HttpGet("progress")]
    public async Task<IActionResult> Progress(CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.ProgressAsync(cancellationToken));

    [HttpPost("steps/{stepCode}/validate")]
    public async Task<IActionResult> Validate(string stepCode, CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.ValidateAsync(stepCode, cancellationToken));

    [HttpPost("steps/{stepCode}/complete")]
    public async Task<IActionResult> Complete(string stepCode, CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.CompleteAsync(stepCode, cancellationToken));

    [HttpGet("next-step")]
    public async Task<IActionResult> Next(CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.NextStepAsync(cancellationToken));

    [HttpGet("readiness")]
    public async Task<IActionResult> Readiness(CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.ReadinessAsync(cancellationToken));

    [HttpGet("activity")]
    public async Task<IActionResult> Activity(CancellationToken cancellationToken) =>
        ApiResult.From(await _onboarding.ActivityAsync(cancellationToken));
}
